# DIを使用したプロジェクトにおける InternalsVisibleTo とフェイククラスを利用したUnitTestの方法
C#の依存性注入（DI）を用いたプロジェクトでは、internal クラスをユニットテストする際にアクセスが制限されているため、テストが難しくなることがあります。これを解決するための一般的な手法として、以下の2つがあります。

InternalsVisibleTo を使用してテストプロジェクトから internal クラスにアクセスできるようにする。
元のクラスを継承したフェイククラスを作成して、テスト用に挙動を変更する。
この記事では、InternalsVisibleTo をプロジェクトファイル（csproj）に設定する方法と、フェイククラスを使った具体的なテストの実装方法を紹介します。

## 1. InternalsVisibleTo を csproj ファイルに設定する方法
internal クラスやメソッドをテストプロジェクトからテストするためには、InternalsVisibleTo 属性を設定します。これをプロジェクトファイル（csproj）に記述することで、テストプロジェクト全体での管理が簡単になります。

設定手順：
テスト対象のプロジェクトの csproj ファイルに以下のように InternalsVisibleTo を追加します。

```xml コードをコピーする
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <!-- テストプロジェクトのアセンブリ名を指定 -->
    <InternalsVisibleTo Include="YourTestProjectName" />
  </ItemGroup>
</Project>
```

この設定により、YourTestProjectName というテストプロジェクトから internal メンバーへアクセスできるようになります。

## 2. フェイククラスを利用した依存関係のモック化
次に、テスト対象の依存関係となるクラスをフェイク化する方法を紹介します。フェイククラスを使用すると、依存関係の振る舞いをテスト用に変更することができ、特定の挙動に集中してテストを行うことができます。

例: フェイククラスを作成してテスト
```csharpコードをコピーする
// 元の ProductService クラス
internal class ProductService
{
    public virtual Product GetProductById(int id)
    {
        return new Product { Id = id, Name = "Real Product" };
    }
}

// フェイククラス
public class FakeProductService : ProductService
{
    public override Product GetProductById(int id)
    {
        // テスト用のフェイク実装
        return new Product { Id = id, Name = "Fake Product" };
    }
}
```
この FakeProductService は ProductService を継承し、テスト用に GetProductById メソッドの挙動を変更しています。これにより、コントローラーなどの依存関係に注入しやすくなります。

テストコード例:
```csharpコードをコピーする
public class ProductControllerTests
{
    [Fact]
    public void GetProduct_ReturnsFakeProduct()
    {
        // Arrange: フェイククラスを使用
        var fakeProductService = new FakeProductService();
        var controller = new ProductController(fakeProductService);

        // Act: テスト対象メソッドを実行
        var result = controller.GetProduct(1);

        // Assert: 結果を確認
        Assert.Equal("Fake Product", result.Name);
    }
}
```
ここでは、FakeProductService を使って ProductController に依存関係を注入しています。このように、フェイククラスを利用することで、DIを活用したプロジェクトでも簡単にユニットテストを行うことができます。

