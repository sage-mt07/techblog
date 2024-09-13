# Roslynを利用例 
Roslynを利用して、ExecuteAsyncやQueryAsyncメソッドを呼び出しているクラスやメソッドの名前を表示する方法を以下に示します。このコードでは、各メソッドがどのクラス内で、どのメソッドから呼び出されているかを解析します。

## 1. Roslynを使ったコードの実装
以下のコードは、ExecuteAsyncやQueryAsyncメソッドが呼び出される場所と、それを含むクラス名とメソッド名を表示するものです。

``` csharp コードをコピーする
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

class Program
{
    static void Main(string[] args)
    {
        // ソースコードが格納されているディレクトリ
        string sourceCodeDirectory = @"C:\Path\To\Your\SourceCode";

        // ディレクトリ内のすべてのC#ファイルを取得
        var csFiles = Directory.GetFiles(sourceCodeDirectory, "*.cs", SearchOption.AllDirectories);

        foreach (var file in csFiles)
        {
            var code = File.ReadAllText(file);
            var tree = CSharpSyntaxTree.ParseText(code);

            var root = tree.GetRoot();
            var invocations = root.DescendantNodes().OfType<InvocationExpressionSyntax>();

            foreach (var invocation in invocations)
            {
                var memberAccess = invocation.Expression as MemberAccessExpressionSyntax;

                if (memberAccess != null && 
                    (memberAccess.Name.Identifier.Text == "ExecuteAsync" || memberAccess.Name.Identifier.Text == "QueryAsync"))
                {
                    var methodDeclaration = invocation.Ancestors().OfType<MethodDeclarationSyntax>().FirstOrDefault();
                    var classDeclaration = invocation.Ancestors().OfType<ClassDeclarationSyntax>().FirstOrDefault();

                    if (methodDeclaration != null && classDeclaration != null)
                    {
                        var methodName = methodDeclaration.Identifier.Text;
                        var className = classDeclaration.Identifier.Text;

                        Console.WriteLine($"Found stored procedure call in class: {className}, method: {methodName}, file: {file}");

                        var argumentList = invocation.ArgumentList.Arguments;

                        if (argumentList.Count > 0)
                        {
                            var firstArgument = argumentList[0].Expression as LiteralExpressionSyntax;

                            if (firstArgument != null && firstArgument.IsKind(SyntaxKind.StringLiteralExpression))
                            {
                                var storedProcedureName = firstArgument.Token.ValueText;
                                Console.WriteLine($"  Stored Procedure: {storedProcedureName}");
                            }
                        }
                    }
                }
            }
        }
    }
}
``` 

## 2. このコードの説明
クラス名とメソッド名の取得:
invocation.Ancestors().OfType<MethodDeclarationSyntax>() を使って、現在の呼び出しがどのメソッド内にあるかを取得します。
invocation.Ancestors().OfType<ClassDeclarationSyntax>() を使って、そのメソッドがどのクラス内にあるかを取得します。
ExecuteAsyncやQueryAsyncの検出:
memberAccess.Name.Identifier.Text をチェックし、ExecuteAsyncまたはQueryAsyncであることを確認します。
SP名の抽出:
メソッド呼び出しの最初の引数をチェックし、それが文字列リテラル（ストアドプロシージャ名）であれば、SP名を抽出します。
