# cr-bundle

cr-bundle is a CLI tool for bundling [Crystal language](https://crystal-lang.org/)'s source codes into a single file.

## Installation

```sh
$ cd <your favorite directory>
$ git clone https://github.com/yuruhi/cr-bundle.git && cd cd-bundle
$ crystal build --release src/cli.cr -o cr-bundle
$ cp cr-bundle <your favorite bin>
```

## Usage

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

The directory to search can be specified with the environment `CR_BUNDLE_PATH`. If it is not specified, the argument of the `-p` option is used.

For detail `require` sepcification, see [Requiring files - Crystal](https://crystal-lang.org/reference/syntax_and_semantics/requiring_files.html).

## Contributing

1. Fork it (<https://github.com/your-github-user/cr-bundle/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [yuruhi](https://github.com/yuruhi) - creator and maintainer
