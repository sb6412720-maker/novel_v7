"""Extra Inkitt-style catalog seed. Safe to run every startup (insert by title if missing)."""
from __future__ import annotations

import logging
from typing import Any

LOGGER = logging.getLogger(__name__)

# Filenames that map to /uploads/<file> (same names as story_card_images assets).
_COVER_FILES = [
    "c1a4b2d2-7ba9-44ea-9ea9-81873119a8ec.jpg",
    "cf12c459-4fe5-4725-8ca0-01f42b898d21.jpg",
    "d1a0655f-892d-4603-919f-92cdf779dae7.jpg",
    "d7728b65-7fcc-45cc-bfb2-38a47dfea216.jpg",
    "d55997d3-bc48-43a1-a42e-d004598104d0.jpg",
    "dc335f4a-9cf3-498d-8c27-5addd0cb15cf.jpg",
    "dc499710-91bd-4dae-8d0c-145faa5345e2.jpg",
    "de52e8d5-1a1c-43b2-8752-70582d3e6c94.jpg",
    "e65f5659-9564-4623-b4c6-a5c37cb4aa5e.jpg",
    "fdc309b2-20b4-4966-8293-9db4532dd8e3.jpg",
    "8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg",
    "6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg",
    "4463cfc125314397830f91dc63b79d05.jpg",
    "006575b1-f6b5-49b2-b3a4-6a9ef1a1e02e.jpg",
    "3306c2bd5ab844c3afe1e695b3c1e261.jpg",
    "7d7d5cc8-5b0a-4821-9e57-3f58c36998b0.jpg",
    "6a5c2a85-2d8c-498d-9153-1d72ec4005e4.jpg",
    "04d68518-aafb-497e-995e-10bc6e4bef90.jpg",
    "0d88ca6e-bdb9-4d45-b7f4-013f0ef843e5.jpg",
    "19eb26e8-6ee4-4010-8848-8f5779f602dd.jpg",
]


def _c(i: int) -> str:
    """Always store public URL path so Flutter/web resolve via /uploads/."""
    return f"/uploads/{_COVER_FILES[i % len(_COVER_FILES)]}"


# title, author, description, cover, accent, section, status, rating, genre, secondary, sort, completed
INKITT_BOOKS: list[tuple] = [
    ("Rebuilding After Betrayal", "CosmicChaos", "After everything fell apart, she learns how to trust again.", _c(0), "#c45c6a", "trending", "Published", 4.9, "Contemporary Romance", "Drama", 1, 0),
    ("The Easter Bunny", "Michele Dixon", "A single dad, a holiday miracle, and a second chance.", _c(1), "#e8a0b0", "trending", "Published", 4.7, "Contemporary Romance", "Love", 2, 0),
    ("Buried Alive", "CosmicChaos", "Secrets buried for years surface when the past returns.", _c(2), "#6b4c7a", "trending", "Published", 4.7, "Contemporary Romance", "Suspense", 3, 0),
    ("Marked By His Touch", "Ava Reed", "One touch and her carefully built walls begin to crack.", _c(3), "#1a1a2e", "trending", "Published", 4.5, "Contemporary Romance", "Sex", 4, 0),
    ("The Boss Before Feelings", "Nensha Jennifer", "Office rules were simple—until he became more than her boss.", _c(4), "#2c3e50", "trending", "Published", 4.4, "Contemporary Romance", "Love", 5, 0),
    ("Full Volume", "Anne-Marie", "Music, rivalry, and a love that refuses to stay quiet.", _c(5), "#3498db", "trending", "Published", 4.7, "Contemporary Romance", "Drama", 6, 0),
    ("Hit and Run", "Uxcutc", "A chance collision that changes both of their lives.", _c(6), "#e67e22", "trending", "Published", 4.9, "Contemporary Romance", "Romantic Comedy", 7, 0),
    ("If You'd Chosen Me", "AuthorAcacia", "What if she had said yes the first time?", _c(7), "#9b59b6", "trending", "Published", 4.8, "Contemporary Romance", "Love", 8, 0),
    ("Married by Fate", "Alice", "An arranged marriage becomes something real.", _c(8), "#16a085", "trending", "Published", 4.9, "Contemporary Romance", "Drama", 9, 0),
    ("What We Never Healed", "Ava Reed", "Two years later, fate brings them back together.", _c(9), "#8e44ad", "trending", "Published", 4.6, "Contemporary Romance", "Office Romance", 10, 1),
    ("Half-Claimed", "Elle Harper Hayden", "The alpha's claim was only half the story.", _c(10), "#2c1654", "trending", "Published", 4.8, "Werewolves & Shifters", "Werewolves", 11, 0),
    ("THE WOMAN HE BOUGHT", "The Secret Chapter", "He bought her contract. She stole his heart.", _c(11), "#1a1a1a", "trending", "Published", 4.2, "Dark Romance", "Ceo", 12, 0),
    ("The Alpha's Exiled Mate", "Amal A. Usman", "Exiled from the pack, claimed by destiny.", _c(12), "#4a3728", "trending", "Published", 4.4, "Werewolves & Shifters", "Alpha", 13, 0),
    ("Property of Sin", "Lizette Combrinck", "Steel & Sin MC. Book 1.", _c(13), "#c0392b", "trending", "Published", 4.2, "Thriller", "Forced Proximity", 14, 0),
    ("Vampire's Pet", "Cannon", "She was never meant to be his pet.", _c(14), "#7b241c", "trending", "Published", 4.8, "Thriller", "Vampire", 15, 0),
    ("His Accidental Billion-Dollar Bride", "Serena B. Vale", "One paperwork error. One very real marriage.", _c(15), "#1c2833", "trending", "Published", 4.7, "Thriller", "Love", 16, 0),
    ("Poor Little Rich Girl", "topperjoslin", "Money couldn't buy the one thing she needed.", _c(16), "#5d6d7e", "trending", "Published", 4.9, "Thriller", "Drama", 17, 0),
    ("My 21 Brothers", "I_Am_Weird69", "A family secret twenty-one brothers strong.", _c(17), "#f5b041", "trending", "Published", 4.7, "Thriller", "Family", 18, 0),
    ("Furry Humans", "Jariah Weaver", "When the full moon rises, so does the truth.", _c(18), "#1b2631", "trending", "Published", 4.7, "Thriller", "Completed", 19, 1),
    ("Unwanted Twin", "Ree", "The twin they tried to forget.", _c(19), "#17202a", "trending", "Published", 4.7, "Thriller", "Italian Mafia", 20, 0),
    ("A Lab Rat and her Alien", "Nova K", "Science never prepared her for him.", _c(0), "#1abc9c", "recently_updated", "Published", 4.6, "Sci-Fi", "Alien", 21, 0),
    ("A Different Species", "StarWriter", "Between two worlds, only one truth remains.", _c(1), "#2980b9", "recently_updated", "Published", 4.5, "Sci-Fi", "Romance", 22, 0),
    ("Love Beyond Stars", "GalaxyPen", "Light-years apart was never enough to stop them.", _c(2), "#8e44ad", "recently_updated", "Published", 4.8, "Sci-Fi", "Love", 23, 0),
    ("Dark Claim", "NightInk", "He claimed her in the dark—and she claimed him back.", _c(3), "#1a1a1a", "recently_updated", "Published", 4.7, "Dark Romance", "Possessive", 24, 0),
    ("Forbidden Ink", "ScarletPage", "Every mark on her skin told a secret.", _c(4), "#922b21", "recently_updated", "Published", 4.6, "Dark Romance", "Tattoo", 25, 0),
    ("Rainbow Bound", "PrideQuill", "Love has every color—and every risk.", _c(5), "#e91e63", "recently_updated", "Published", 4.9, "LGBTQ+", "Romance", 26, 0),
    ("His Secret", "TrueNorth", "Coming out was only the beginning.", _c(6), "#3498db", "recently_updated", "Published", 4.5, "LGBTQ+", "Drama", 27, 0),
    ("Moonbound Heart", "PackTales", "The mate bond never lies.", _c(7), "#4a235a", "recently_updated", "Published", 4.8, "Werewolves & Shifters", "Mate", 28, 0),
    ("Alpha's Second Chance", "WolfMoon", "Rejected once. Chosen forever.", _c(8), "#6c3483", "recently_updated", "Published", 4.7, "Werewolves & Shifters", "Alpha", 29, 0),
    ("Shadow Pack", "LunaWrite", "Not all packs are born of blood.", _c(9), "#1c2833", "recently_updated", "Published", 4.4, "Werewolves & Shifters", "Pack", 30, 0),
    ("His Dark Forever", "Mai-Dee", "Some love stories last a thousand nights.", _c(10), "#2c3e50", "featured", "Published", 5.0, "Romance", "Love Story", 31, 0),
    ("Her Obsessed Stepbrother", "Annie", "Obsession was never supposed to feel this right.", _c(11), "#7d3c98", "featured", "Published", 5.0, "Dark Romance", "Dark", 32, 0),
    ("A Little Less Room", "Paul Wolfe", "A short story about space, silence, and staying.", _c(12), "#1a252f", "featured", "Published", 4.8, "Drama", "Dark", 33, 0),
    ("Please Stay on the Line", "Paul Wolfe", "Sometimes all someone needs is a voice.", _c(13), "#17202a", "featured", "Published", 4.9, "Thriller", "Suspense", 34, 0),
    ("YOUTH NOVELL - MORE THAN FRIENDS", "VulcanoJesse", "High school was never just high school.", _c(14), "#f39c12", "featured", "Published", 4.7, "Young Adult", "Friendship", 35, 0),
    ("The Pack - On the Run", "Marcy", "Hunted. United. Unbroken.", _c(15), "#5d6d7e", "featured", "Published", 4.4, "Thriller", "Mystery/Sci Fi", 36, 0),
    ("The Golden Cage", "Tara", "Luxury was the trap.", _c(16), "#1c2833", "featured", "Published", 5.0, "Thriller", "Stalker", 37, 0),
    ("Diary Of Nobody", "K. Haze", "Pages no one was meant to read.", _c(17), "#7D6A5A", "recently_completed", "Completed", 4.1, "Poetry", "Drama", 38, 1),
    ("Warrior Wolves, M.C.", "Lexi Melton", "Brothers by oath. Warriors by blood.", _c(18), "#4A4A62", "recently_completed", "Completed", 4.8, "Thriller", "MC", 39, 1),
    ("Love in Full Color", "Contest Winner", "Every kind of love, every kind of story.", _c(19), "#ff00cc", "trending", "Published", 4.9, "Romance", "Contest", 40, 0),
]

INKITT_READING_LISTS = [
    ("Finished Reading", "PhoenixWerewolf", 13),
    ("Heart Breaking", "Jasmine N", 8),
    ("Mafia", "Anjola", 11),
    ("Update?", "abcya", 26),
    ("Mine", "Debbie Waters", 13),
    ("Fantasy", "Therese Simek", 10),
    ("Vampire", "Gillian", 10),
]

INKITT_CONTESTS = [
    ("Love in Full Color", "Every kind of love, every kind of story. Writing Contest 2026.", "Open entry", 1, 1),
    ("Beyond the Page Audiobook Contest", "Some stories are meant to be heard. 1st place $1000.", "Open entry", 1, 0),
    ("Dark Romance Challenge", "Forbidden love, tension, and second chances.", "Open entry", 1, 0),
    ("Myth Weaver", "Mythology-inspired romance or drama.", "Open entry", 1, 0),
]


def ensure_inkitt_catalog(execute_write, fetch_all, USE_SQLITE: bool) -> dict[str, Any]:
    """Insert missing books, normalize covers, seed lists + contests."""
    added = 0
    covers_fixed = 0

    for (
        title,
        author,
        description,
        cover_path,
        accent_hex,
        section_name,
        status_text,
        rating,
        primary_genre,
        secondary_genre,
        sort_order,
        is_completed,
    ) in INKITT_BOOKS:
        try:
            rows = fetch_all("SELECT id, cover_path FROM books WHERE title=%s LIMIT 1", (title,))
            if rows:
                # Fix legacy cover paths to /uploads/...
                row = rows[0]
                existing = ""
                if isinstance(row, dict):
                    existing = str(row.get("cover_path") or "")
                    book_id = row.get("id")
                else:
                    book_id = row[0]
                    existing = str(row[1] if len(row) > 1 else "")
                if existing and not existing.startswith(("/uploads/", "http")):
                    fname = existing.split("/")[-1]
                    execute_write(
                        "UPDATE books SET cover_path=%s WHERE id=%s",
                        (f"/uploads/{fname}", book_id),
                    )
                    covers_fixed += 1
                continue
            execute_write(
                """
                INSERT INTO books (
                    title, author, description, cover_path, accent_hex, section_name, status_text,
                    rating, genre, primary_genre, secondary_genre, cta_label, sort_order, is_completed
                ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """,
                (
                    title,
                    author,
                    description,
                    cover_path,
                    accent_hex,
                    section_name,
                    status_text,
                    float(rating),
                    primary_genre,
                    primary_genre,
                    secondary_genre,
                    "Read now",
                    int(sort_order),
                    int(is_completed),
                ),
            )
            added += 1
        except Exception as exc:
            LOGGER.warning("inkitt seed book failed %s: %s", title, exc)

    # Normalize any remaining non-/uploads covers project-wide (best effort)
    try:
        bad = fetch_all(
            "SELECT id, cover_path FROM books WHERE cover_path IS NOT NULL AND cover_path != '' AND cover_path NOT LIKE '/uploads/%%' AND cover_path NOT LIKE 'http%%' LIMIT 200"
        )
        for row in bad or []:
            if isinstance(row, dict):
                bid, cp = row.get("id"), str(row.get("cover_path") or "")
            else:
                bid, cp = row[0], str(row[1] if len(row) > 1 else "")
            if not cp:
                continue
            fname = cp.split("/")[-1]
            if fname:
                execute_write("UPDATE books SET cover_path=%s WHERE id=%s", (f"/uploads/{fname}", bid))
                covers_fixed += 1
    except Exception as exc:
        LOGGER.warning("cover normalize pass failed: %s", exc)

    lists_added = 0
    try:
        for name, owner, count in INKITT_READING_LISTS:
            exists = fetch_all("SELECT id FROM reading_lists WHERE name=%s LIMIT 1", (name,))
            if exists:
                continue
            execute_write(
                """
                INSERT INTO reading_lists (user_id, profile_id, name, story_count, cover_path, sort_order)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (None, None, name, int(count), _c(lists_added), lists_added),
            )
            lists_added += 1
    except Exception as exc:
        LOGGER.warning("reading list seed failed: %s", exc)

    contests_added = 0
    try:
        # Table may be created by contests module; try insert
        for title, theme, deadline, active, neon in INKITT_CONTESTS:
            exists = fetch_all("SELECT id FROM contests WHERE title=%s LIMIT 1", (title,))
            if exists:
                continue
            execute_write(
                """
                INSERT INTO contests (title, theme, deadline, is_active, is_neon)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (title, theme, deadline, int(active), int(neon)),
            )
            contests_added += 1
    except Exception as exc:
        LOGGER.warning("contest seed deferred (table may not exist yet): %s", exc)

    result = {
        "books_added": added,
        "covers_fixed": covers_fixed,
        "lists_added": lists_added,
        "contests_added": contests_added,
        "catalog_size": len(INKITT_BOOKS),
    }
    LOGGER.info("inkitt_seed: %s", result)
    return result
