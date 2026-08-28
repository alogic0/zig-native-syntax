export def main [
    input: path
    --format (-f): string = "html"
    ...rest: string
] -> record<path: string, size: int> {
    let files = glob $"($input)/**/*.md"
    $files
        | each {|file| {
            path: $file
            size: ($file | path expand | path type)
        }}
        | where size > 0
        | sort-by size
}

module helpers {
    export def normalize [value: string] {
        $value | str trim | str downcase
    }
}

use helpers normalize
const enabled = true # exported by configuration
const label = "viewer\nresult"
^git --version
