#!/usr/bin/env python3
# @bootwitch:component
# Name: {{SCRIPT_NAME}}.py
# Type: script
# Dates: Created: {{SCRIPT_CREATED_DATE}} | Last Updated: {{SCRIPT_UPDATED_DATE}}
# Version: 0.1.0
# Purpose: Count whitespace-separated words and show their frequencies.
# Arguments: Optional --text TEXT and --top COUNT; --help explains both.
# Output: Total and unique word counts, followed by the most frequent words.
# Returns: Exit status 0 on success or 2 for invalid command-line options.
# Dependencies: Python 3 standard library: argparse and collections.Counter.
# Reads: Text supplied on the command line or the built-in example.
# Writes: None.
# Safety: No file, network, or shell-command access; does not install packages.
# Example: python3 {{SCRIPT_AREA}}/{{SCRIPT_NAME}}.py --text "Bash bash Python" --top 2
# @bootwitch:end

"""A small annotated Python script to explore functions, imports, and loops."""

import argparse  # Standard-library helper for --help and validated options.
from collections import Counter  # Import one class from a standard-library module.


# @bootwitch:function
# Name: count_words
# Purpose: Count each whitespace-separated word, ignoring letter case.
# Arguments: text is the string to inspect.
# Output: None; the count is returned to the caller.
# Returns: A Counter mapping normalized words to their occurrence counts.
# Reads: Only the supplied text.
# Writes: None.
# Safety: Does not read files or execute commands; punctuation stays attached to words.
# @bootwitch:end
def count_words(text: str) -> Counter:
    counts = Counter()
    for word in text.split():
        counts[word.casefold()] += 1
    return counts


# @bootwitch:function
# Name: main
# Purpose: Parse command-line options and print a short word-count report.
# Arguments: Optional argv list; None reads the command line.
# Output: Prints counts to standard output or usage errors to standard error.
# Returns: 0 on success; argparse exits with status 2 for invalid options.
# Reads: Command-line arguments or the built-in example.
# Writes: None.
# Safety: Uses argparse for input validation and never treats text as code.
# @bootwitch:end
def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Count words in a short piece of text.")
    parser.add_argument("--text", default="Bash bash Python", help="text to count")
    parser.add_argument("--top", type=int, default=5, help="number of frequent words to show")
    args = parser.parse_args(argv)
    if args.top < 1:
        parser.error("--top must be a positive number")

    counts = count_words(args.text)
    print(f"Total words: {sum(counts.values())}")
    print(f"Unique words: {len(counts)}")
    for word, count in counts.most_common(args.top):
        print(f"{word}: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
