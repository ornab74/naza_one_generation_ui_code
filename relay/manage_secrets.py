#!/usr/bin/env python3
"""Initialize/update the encrypted relay secrets database."""

from getpass import getpass

from server import EncryptedSecrets


def main() -> None:
    store = EncryptedSecrets()
    values = {
        "openai_api_key": getpass("OpenAI API key (blank to keep): "),
        "meta_muse_api_key": getpass("Meta Muse API key (blank to keep): "),
        "xai_api_key": getpass("xAI API key (blank to keep): "),
    }
    for name, value in values.items():
        if value:
            store.set(name, value)
    print("Encrypted relay secrets updated in relay/secrets.db")


if __name__ == "__main__":
    main()
