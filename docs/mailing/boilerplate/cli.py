"""Small operational CLI for the mailing boilerplate."""
import argparse
from . import db
from .sender import send_batch

def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)

    commands.add_parser("init")
    add = commands.add_parser("add-contact")
    add.add_argument("email")
    add.add_argument("name", nargs="?", default="")

    campaign = commands.add_parser("create-campaign")
    campaign.add_argument("name")
    campaign.add_argument("subject")

    send = commands.add_parser("send")
    send.add_argument("campaign")
    send.add_argument("--subject", default="Campaign update")
    send.add_argument("--limit", type=int, default=25)
    send.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()
    if args.command == "init":
        db.init()
        print("Database initialized")
    elif args.command == "add-contact":
        db.init()
        db.add_contact(args.email, args.name)
        print("Contact added")
    elif args.command == "create-campaign":
        db.init()
        with db.connect() as connection:
            connection.execute(
                "INSERT OR REPLACE INTO campaigns(name, subject) VALUES (?, ?)",
                (args.name, args.subject),
            )
        print("Campaign created")
    elif args.command == "send":
        db.init()
        results = send_batch(args.campaign, args.subject, args.limit, args.dry_run)
        sent = sum(1 for item in results if item["status"] in ("sent", "dry-run"))
        failed = len(results) - sent
        print("Processed: {0}; successful: {1}; failed: {2}".format(len(results), sent, failed))

if __name__ == "__main__":
    main()
