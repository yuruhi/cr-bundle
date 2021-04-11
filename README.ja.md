# cr-bundle

cr-bundle は与えられた [Crystal](https://ja.crystal-lang.org/) 言語のファイルの中の `require "foo"` を展開して一つのファイルに束ねる CLI ツールです。

## インストール

Crystal 言語のインストールが必要です。インストール方法は [インストール - プログラミング言語 Crystal](https://ja.crystal-lang.org/install/) をご覧ください。

```sh
$ cd <your favorite directory>
$ git clone https://github.com/yuruhi/cr-bundle.git && cd cd-bundle
$ crystal build --release src/cli.cr -o cr-bundle
$ cp cr-bundle <your favorite bin>
```

## 使い方

```
cr-bundle is a crystal language's bundler.

usage: cr-bundle [programfile]

    -v, --version                    show the cr-bundle version number
    -h, --help                       show this help message
    -e SOURCE, --eval SOURCE         eval code from args
    -i, --inplace                    inplace edit
    -p PATH, --path PATH             indicate require path
```

```crystal
$ cat a.cr
require "./b"
puts "a.cr"

$ cat b.cr
puts "b.cr"

$ cr-bundle a.cr
# require "./b"
puts "b.cr"

puts "a.cr"
```

探索の対象となるディレクトリは環境変数 `CR_BUNDLE_PATH` で指定できます。指定されていない場合は `-p` オプションの引数が使用されます。

詳しい `require` の仕様については [ファイルの require - Crystal](https://ja.crystal-lang.org/reference/syntax_and_semantics/requiring_files.html) をご覧ください。

## Contributing

1. Fork it (<https://github.com/your-github-user/cr-bundle/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

-   [yuruhi](https://github.com/yuruhi) - creator and maintainer
