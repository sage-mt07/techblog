# NET 8 から aspnet_regiis で暗号化した app.config を COM を利用して読み取る方法
## 1. 暗号化された app.config ファイルの準備
まず、aspnet_regiis を使用して app.config の特定のセクションを暗号化します。例えば、connectionStrings セクションを暗号化する場合は、次のようにコマンドを実行します。

``` bash コードをコピーする
aspnet_regiis -pef "connectionStrings" "C:\Path\To\YourProject"
``` 
これにより、app.config の connectionStrings セクションが暗号化されます。

## 2. .NET Framework で COM を利用して app.config を読み取るクラスを作成
ConfigurationManager を使用して app.config を読み取り、必要に応じて復号化するクラスを .NET Framework で作成し、COM 経由で利用できるようにします。

コード例: ConfigurationDecriptor クラス
``` csharp コードをコピーする
using System;
using System.Configuration;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using Newtonsoft.Json;

namespace DecryptAppConfig
{
    [ComVisible(true)]
    [Guid("13d6786a-1431-4ba5-a485-ea2e4bd87609")]
    public class ConfigurationDecriptor
    {
        public string DecryptAppConfigAsJson()
        {
            // Get the current configuration file
            Configuration config = ConfigurationManager.OpenExeConfiguration(ConfigurationUserLevel.None);

            var settings = new Dictionary<string, List<KeyValuePair<string, string>>>();

            // Decrypt the connectionStrings section if it's encrypted
            ConfigurationSection connectionStringsSection = config.GetSection("connectionStrings");
            if (connectionStringsSection.SectionInformation.IsProtected)
            {
                connectionStringsSection.SectionInformation.UnprotectSection();
                ConfigurationManager.RefreshSection("connectionStrings");
            }

            // Store connectionStrings
            var connectionStrings = new List<KeyValuePair<string, string>>();
            foreach (ConnectionStringSettings connStr in config.ConnectionStrings.ConnectionStrings)
            {
                connectionStrings.Add(new KeyValuePair<string, string>(connStr.Name, connStr.ConnectionString));
            }
            settings["ConnectionStrings"] = connectionStrings;

            // Decrypt the appSettings section if it's encrypted
            ConfigurationSection appSettingsSection = config.GetSection("appSettings");
            if (appSettingsSection.SectionInformation.IsProtected)
            {
                appSettingsSection.SectionInformation.UnprotectSection();
                ConfigurationManager.RefreshSection("appSettings");
            }

            // Store appSettings
            var appSettings = new List<KeyValuePair<string, string>>();
            foreach (string key in config.AppSettings.Settings.AllKeys)
            {
                appSettings.Add(new KeyValuePair<string, string>(key, config.AppSettings.Settings[key].Value));
            }
            settings["AppSettings"] = appSettings;

            // Return settings as JSON
            return JsonConvert.SerializeObject(settings);
        }
    }
}
``` 
## 3. COM オブジェクトの登録
ConfigurationDecriptor クラスを含む DLL をビルドした後、RegAsm ツールを使用して DLL を COM に登録します。

``` bash コードをコピーする
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\regasm.exe /codebase "C:\Path\To\Your\DLL\DecryptAppConfig.dll"
``` 
これにより、ConfigurationDecriptor クラスが COM オブジェクトとして登録され、他のアプリケーションから利用可能になります。

## 4. .NET 8 アプリケーションから COM オブジェクトを使用
.NET 8 アプリケーションから ConfigurationDecriptor COM オブジェクトを利用して、暗号化された app.config の内容を読み取ります。

コード例: .NET 8 アプリケーションでの使用
``` csharp コードをコピーする
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using Newtonsoft.Json;

class Program
{
    static void Main(string[] args)
    {
        // COMオブジェクトのタイプを取得
        Type decryptorType = Type.GetTypeFromProgID("DecryptAppConfig.ConfigurationDecriptor");

        // COMオブジェクトのインスタンスを作成
        dynamic decryptor = Activator.CreateInstance(decryptorType);

        // DecryptAppConfigAsJsonメソッドを呼び出し、復号化された設定をJSON形式で取得
        string jsonConfig = decryptor.DecryptAppConfigAsJson();

        // JSONを解析
        var config = JsonConvert.DeserializeObject<Dictionary<string, List<KeyValuePair<string, string>>>>(jsonConfig);

        // 設定の使用例
        if (config.TryGetValue("ConnectionStrings", out var connectionStrings))
        {
            foreach (var connStr in connectionStrings)
            {
                Console.WriteLine($"Connection String Name: {connStr.Key}, Value: {connStr.Value}");
            }
        }

        if (config.TryGetValue("AppSettings", out var appSettings))
        {
            foreach (var setting in appSettings)
            {
                Console.WriteLine($"AppSetting Key: {setting.Key}, Value: {setting.Value}");
            }
        }

        // COMオブジェクトのインスタンスを解放
        Marshal.ReleaseComObject(decryptor);
    }
}
``` 
## 5. Newtonsoft.Json の配置
.NET Framework の ConfigurationDecriptor クラスで Newtonsoft.Json を使用しているため、Newtonsoft.Json.dll は COM クラスと同じディレクトリに配置するか、GAC に登録する必要があります。

同じディレクトリに配置する場合
DecryptAppConfig.dll と Newtonsoft.Json.dll を同じディレクトリに配置します。
GAC に登録する場合
gacutil -i "C:\Path\To\Newtonsoft.Json.dll" を使用して GAC に Newtonsoft.Json.dll を登録します。