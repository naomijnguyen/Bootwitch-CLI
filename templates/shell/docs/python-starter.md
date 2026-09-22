# Learn with the Python starter

The project-local generator can make a runnable, annotated Python example without installing any third-party packages:

```bash
bash wrappers/new_script.command word-demo scripts --language python
python3 scripts/word-demo.py --help
python3 scripts/word-demo.py --text "Bash bash Python" --top 2
```

The default generator language is still Bash. Python is an explicit choice and requires `python3` to run. The generated file is yours to edit; the `@bootwitch` comments let the documentation builder explain the component without executing it.

Start with `from collections import Counter`. An **import** gives this script a reusable class from Python's standard library. `def count_words(text: str) -> Counter:` defines *your own* function: it receives text and returns counts. Inside it, `for word in text.split():` visits each whitespace-separated piece, and `counts[word.casefold()] += 1` increments that word's count without treating uppercase and lowercase as different words. The `return` statement hands the result back to `main()`.

`argparse` turns `--text` and `--top` into command-line options and provides `--help` and useful errors. The second loop prints the most frequent words. Try changing the example text, adding another option, or importing `count_words` from another Python file. No package install is needed for either standard-library import.

This is a learning example, not a full text tokenizer: it splits on whitespace, so `word` and `word,` count separately. If you need punctuation-aware tokenization later, that can be a deliberate next module rather than hidden complexity in a first script.
