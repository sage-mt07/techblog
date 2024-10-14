using IBMMQ;
using System.Collections.Concurrent;
using System.Net;

namespace MQPool
{
    public class ConnectionPool : IDisposable
    {
        private HashSet<string> _failedServers = new HashSet<string>();
        private List<string> _servers;
        private ConcurrentDictionary<string,MQQueueManager> _queueManagers = new();
        private ConcurrentQueue<ManageQueue> _getQueue = new();
        private ConcurrentQueue<ManageQueue> _putQueue = new();
        private int _concurrentNumber = 0;
        private string _putQueueName;
        private string _getQueueName;
        private bool _disposed = false;

        public ConnectionPool(IEnumerable<string> servers, string getQueueName, string putQueueName, int concurrentNumber)
        {
            _concurrentNumber = concurrentNumber;
            _putQueueName = putQueueName;
            _getQueueName = getQueueName;
            _servers = new List<string>(servers);
            RecoveryServer();
        }

        public void Initialize()
        {
            SetAvailableServer(_servers, delegate (string svn)
            {
                lock (_failedServers)
                {
                    _failedServers.Add(svn);
                }
            });
        }

        private void SetAvailableServer(IEnumerable<string> servers, Action<string> failAction = null)
        {
            foreach (var server in servers)
            {
                try
                {
                    var mq = new MQQueueManager();
                    _queueManagers.AddOrUpdate(server, (string svn) => { return mq; }, 
                        (string svn, MQQueueManager mqt) => 
                    { 
                        mqt.Dispose(); 
                        return mq; 
                    });
                    for (int i = 0; i < _concurrentNumber; i++)
                    {
                        var getQueue = mq.AccessQueue(_getQueueName, MQC.MQOO_INPUT_AS_Q_DEF | MQC.MQOO_OUTPUT);
                        var manageGQueue = new ManageQueue(getQueue, server);
                        manageGQueue.DisposeHandler += delegate (object? _, MQQueue queue) { _getQueue.Enqueue(manageGQueue); };
                        manageGQueue.MarkAsFailedHandler += delegate (object? _, string failedServer)
                        {
                            DisposeQueue(failedServer, _getQueue);
                            DisposeQueue(failedServer, _putQueue);
                            if(_queueManagers.TryGetValue(failedServer, out var mq))
                            {
                                mq.Disconnect();
                                _queueManagers.TryRemove(failedServer, out mq);
                            }

                            failAction?.Invoke(failedServer);
                        };
                        _getQueue.Enqueue(manageGQueue);

                        var putQueue = mq.AccessQueue(_putQueueName, MQC.MQOO_INPUT_AS_Q_DEF | MQC.MQOO_OUTPUT);
                        var managePQueue = new ManageQueue(putQueue, server);
                        managePQueue.DisposeHandler += delegate (object? _, MQQueue queue) { _putQueue.Enqueue(managePQueue); };
                        managePQueue.MarkAsFailedHandler += delegate (object? _, string failedServer)
                        {
                            DisposeQueue(failedServer, _getQueue);
                            DisposeQueue(failedServer, _putQueue);
                            if (_queueManagers.TryGetValue(failedServer, out var mq))
                            {
                                mq.Disconnect();
                                _queueManagers.TryRemove(failedServer, out mq);
                            }
                            failAction?.Invoke(failedServer);
                        };
                        _putQueue.Enqueue(managePQueue);
                    }
                }
                catch (MQException e)
                {
                    // Log exception details for debugging
                    Console.WriteLine($"Failed to connect to server {server}: {e.Message}");
                    failAction?.Invoke(server);
                }
            }
        }

        private void DisposeQueue(string server, ConcurrentQueue<ManageQueue> target)
        {
            var current = target.Count;
            for (int i = 0; i < current; i++)
            {
                if (target.TryDequeue(out var localQueue))
                {
                    if (localQueue.GetServer != server)
                    {
                        target.Enqueue(localQueue);
                    }
                    else
                    {
                        localQueue.Dispose();
                    }
                }
            }
        }

        private void RecoveryServer()
        {
            Task.Run(async () =>
            {
                while (true)
                {
                    lock (_failedServers)
                    {
                        if (_failedServers.Count > 0)
                        {
                            var serversToRecover = _failedServers.ToList();
                            _failedServers.Clear();
                            SetAvailableServer(serversToRecover, delegate (string svn)
                            {
                                _failedServers.Add(svn);
                            });
                        }
                    }
                    await Task.Delay(1000 * 60); // Retry every 1 minute
                }
            });
        }

        public async Task<ManageQueue> GetQueueAsync()
        {
            while (true)
            {
                if (_getQueue.TryDequeue(out var result))
                {
                    return result;
                }
                await Task.Delay(100); // Reduced delay for quicker retries
            }
        }

        public async Task<ManageQueue> PutQueueAsync()
        {
            while (true)
            {
                if (_putQueue.TryDequeue(out var result))
                {
                    return result;
                }
                await Task.Delay(100); // Reduced delay for quicker retries
            }
        }

        public void Dispose()
        {
            if (!_disposed)
            {
                foreach(var key in _queueManagers.Keys)
                {
                    _queueManagers[key].Disconnect();
                    _queueManagers[key].Dispose();

                }
                _disposed = true;
            }
        }
    }

    public class ManageQueue : IDisposable
    {
        private MQQueue _queue;
        private string _server;
        public string GetServer { get { return _server; } }
        public EventHandler<MQQueue> DisposeHandler { get; set; }
        public EventHandler<string> MarkAsFailedHandler { get; set; }

        public ManageQueue(MQQueue queue, string server)
        {
            _queue = queue;
            _server = server;
        }

        public MQQueue Queue { get { return _queue; } }

        public void Dispose()
        {
            if (_queue != null)
            {
                DisposeHandler?.Invoke(this, _queue);
                _queue.Close();
                _queue = null;
            }
        }

        public void MarkAsFail()
        {
            if (MarkAsFailedHandler != null)
            {
                MarkAsFailedHandler(this, _server);
            }
            _queue?.Dispose();
            _queue = null;
        }
    }
}