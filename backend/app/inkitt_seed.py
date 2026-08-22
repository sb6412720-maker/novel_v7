"""Extra Inkitt-style catalog seed. Safe to run every startup (insert by title if missing)."""
from __future__ import annotations

import logging
from typing import Any

LOGGER = logging.getLogger(__name__)

# Reuse existing cover files from the project seed set (rotated).
_C = [
    "story_card_images/c1a4b2d2-7ba9-44ea-9ea9-81873119a8ec.jpg",
    "story_card_images/cf12c459-4fe5-4725-8ca0-01f42b898d21.jpg",
    "story_card_images/d1a0655f-892d-4603-919f-92cdf779dae7.jpg",
    "story_card_images/d7728b65-7fcc-45cc-bfb2-38a47dfea216.jpg",
    "story_card_images/d55997d3-bc48-43a1-a42e-d004598104d0.jpg",
    "story_card_images/dc335f4a-9cf3-498d-8c27-5addd0cb15cf.jpg",
    "story_card_images/dc499710-91bd-4dae-8d0c-145faa5345e2.jpg",
    "story_card_images/de52e8d5-1a1c-43b2-8752-70582d3e6c94.jpg",
    "story_card_images/e65f5659-9564-4623-b4c6-a5c37cb4aa5e.jpg",
    "story_card_images/fdc309b2-20b4-4966-8293-9db4532dd8e3.jpg",
    "story_card_images/8de846ae-c1cc-4e8b-a52e-e8aa48b6abb1.jpg",
    "story_card_images/6290b4c8-83e9-4d5d-a740-06d4ec94d335.jpg",
]

def _c(i: int) -> str:
    return _C[i % len(_C)]


# title, author, description, cover, accent, section, status, rating, genre, secondary, sort, completed
INKITT_BOOKS: list[tuple] = [
    # Contemporary Romance
    ("Rebuilding After Betrayal", "CosmicChaos", "After everything fell apart, she learns how to trust again.", _c(0), "#c45c6a", "trending", "Published", 4.9, "Contemporary Romance", "Drama", 1, 0),
    ("The Easter Bunny", "Michele Dixon", "A single dad, a holiday miracle, and a second chance.", _c(1), "#e8a0b0", "trending", "Published", 4.7, "Contemporary Romance", "Love", 2, 0),
    ("Buried Alive", "CosmicChaos", "Secrets buried for years surface when the past returns.", _c(2), "#6b4c7a", "trending", "Published", 4.7, "Contemporary Romance", "Suspense", 3, 0),
    ("Marked By His Touch", "Ava Reed", "One touch and her carefully built walls begin to crack.", _c(3), "#1a1a2e", "trending", "Published", 4.5, "Contemporary Romance", "Sex", 4, 0),
    ("The Boss Before Feelings", "Nensha Jennifer", "Office rules were simple—until he became more than her boss.", _c(4), "#2c3e50", "trending", "Published", 4.4, "Contemporary Romance", "Love", 5, 0),
    ("Full Volume", "Anne-Marie", "Music, rivalry, and a love that refuses to stay quiet.", _c(5), "#3498db", "trending", "Published", 4.7, "Contemporary Romance", "Drama", 6, 0),
    ("Hit and Run", "Uxcutc", "A chance collision that changes both of their lives.", _c(6), "#e67e22", "trending", "Published", 4.9, "Contemporary Romance", "Romance", 7, 0),
    ("Married by Fate", "Alice", "A marriage of convenience that becomes something real.", _c(7), "#f5d0c5", "trending", "Published", 4.9, "Contemporary Romance", "Sex", 8, 0),
    ("If You'd Chosen Me", "AuthorAcacia", "She was always second—until someone finally chose her first.", _c(8), "#f8e9a1", "trending", "Published", 5.0, "Contemporary Romance", "Unrequited Love", 9, 0),
    # Dark Romance
    ("What We Never Healed", "Ava Reed", "Two years ago he chose his career. Fate brings them back together.", _c(9), "#8b0000", "trending", "Published", 4.7, "Dark Romance", "Alpha", 10, 1),
    ("Half-Claimed", "Elle Harper Hayden", "An alpha twins revenge that blurs the line between hate and desire.", _c(10), "#4a0e4e", "trending", "Published", 4.7, "Dark Romance", "Werewolf", 11, 0),
    ("THE WOMAN HE BOUGHT", "The Secret Chapter", "Bought as leverage. Kept for reasons he refuses to name.", _c(11), "#2d1b1b", "trending", "Published", 4.2, "Dark Romance", "Revenge", 12, 0),
    ("His Brother's Mate", "Drowned Abyss", "The wrong brother. The right bond. Forbidden from the start.", _c(0), "#1c1c1c", "trending", "Published", 4.8, "Dark Romance", "Werewolf", 13, 0),
    ("THE BLOOD DEBT", "Alice", "A debt paid in blood—and something far more intimate.", _c(1), "#5c0000", "trending", "Published", 4.8, "Dark Romance", "Death", 14, 0),
    ("The Golden Cage", "Tara", "Luxury was the cage. He was the lock.", _c(2), "#c9a227", "trending", "Published", 5.0, "Dark Romance", "Love", 15, 0),
    ("Let me Hate you", "Anjaani Sadek", "Hate was safer than falling for him again.", _c(3), "#3d0c11", "trending", "Published", 4.8, "Dark Romance", "Dominantmale", 16, 0),
    ("Book One: Rejecting My Ruthless Alpha Mate", "Amal A. Usman", "She rejected him once. He never forgot.", _c(4), "#0f0f0f", "trending", "Published", 4.6, "Dark Romance", "Love", 17, 0),
    # Thriller
    ("Warrior Wolves, M.C.", "topperjoslin", "An MC thriller where loyalty cuts deeper than steel.", _c(5), "#2c3e50", "recently_updated", "Published", 4.8, "Thriller", "Slow Burn", 18, 0),
    ("The Pack - On the Run (unedited)", "Marcy", "On the run from a pack that wants her silenced.", _c(6), "#34495e", "recently_updated", "Published", 4.4, "Thriller", "Suspense", 19, 0),
    ("Vampire's Pet", "Cannon", "Captured. Claimed. Learning to survive as his pet.", _c(7), "#1a0000", "recently_updated", "Published", 4.8, "Thriller", "Vampire", 20, 0),
    ("Property of Sin", "LizetteCombrinck", "Steel & Sin MC—property means protection, and possession.", _c(8), "#4a3728", "recently_updated", "Published", 4.2, "Thriller", "Mc Romance", 21, 0),
    ("Poor Little Rich Girl", "topperjoslin", "Money couldn't buy her freedom—or his mercy.", _c(9), "#d4af37", "recently_updated", "Published", 4.9, "Thriller", "Suspense", 22, 0),
    ("His Accidental Billion-Dollar Bride", "Serena B. Vale", "One mistake, one marriage, one empire on the line.", _c(10), "#ecf0f1", "recently_updated", "Published", 4.7, "Thriller", "Love Story", 23, 0),
    ("My 21 Brothers", "I_Am_Weird69", "Twenty-one protectors. One secret she can't keep.", _c(11), "#7f8c8d", "recently_updated", "Published", 4.7, "Thriller", "Mafia", 24, 0),
    ("Furry Humans", "Jariah Weaver", "When the line between human and beast disappears.", _c(0), "#27ae60", "recently_updated", "Published", 4.7, "Thriller", "History", 25, 0),
    # Sci-Fi
    ("A Lab Rat and her Alien", "E_L_B_SMITH", "She was the experiment. He was the escape.", _c(1), "#16a085", "recently_completed", "Published", 4.9, "Sci-Fi", "Romance", 26, 0),
    ("A Different Species", "biancapv", "Humanity was never the only species watching.", _c(2), "#2980b9", "recently_completed", "Published", 4.7, "Sci-Fi", "Science Fantasy", 27, 0),
    ("Furry Humans: Origins", "Jariah Weaver", "Before the world knew, the change had already begun.", _c(3), "#8e44ad", "recently_completed", "Published", 4.7, "Sci-Fi", "History", 28, 0),
    ("Twin Hearts", "Leslee Kahler", "Two souls, one fate, across the stars.", _c(4), "#e74c3c", "recently_completed", "Published", 4.9, "Sci-Fi", "Love", 29, 0),
    ("Wrench's Girl", "sjwilke", "Grease, grit, and a girl who refuses to be left behind.", _c(5), "#f39c12", "recently_completed", "Published", 4.5, "Sci-Fi", "Romance", 30, 0),
    ("Her Gift", "Kara Elle", "A power she never asked for—and a war that needs it.", _c(6), "#c0392b", "recently_completed", "Published", 4.8, "Sci-Fi", "Mature", 31, 0),
    ("The Lost Alpha", "siarra22", "An alpha without a pack. A world without rules.", _c(7), "#2c3e50", "recently_completed", "Published", 4.6, "Sci-Fi", "Werewolf", 32, 0),
    ("The Guardian: A Journey Begins", "E.J. Wedge", "Mountains, monsters, and a guardian's first trial.", _c(8), "#1abc9c", "recently_completed", "Published", 4.6, "Sci-Fi", "Friendship", 33, 0),
    ("Gloom (complete)", "icyandotheremotions", "When the light goes out, something else wakes up.", _c(9), "#0d0d0d", "recently_completed", "Completed", 4.8, "Sci-Fi", "Monster", 34, 1),
    # LGBTQ+
    ("Yours Anyway", "Kex Harper", "He was never supposed to fall—for him.", _c(10), "#e91e63", "trending", "Published", 4.8, "LGBTQ+", "Gaydrama", 35, 0),
    ("Poisoned Light", "Magnus_K", "Light that heals. Poison that binds.", _c(11), "#9b59b6", "trending", "Published", 4.6, "LGBTQ+", "Lgbt", 36, 0),
    ("Acceptance", "AstridCross", "Learning to accept himself—and the one who already did.", _c(0), "#34495e", "trending", "Published", 4.8, "LGBTQ+", "Smut", 37, 0),
    ("High School Boys", "AJ Wylder", "Senior year secrets and a love they can't name yet.", _c(1), "#e74c3c", "trending", "Published", 4.8, "LGBTQ+", "Love", 38, 0),
    ("Truck Stop", "poppingdaisies", "A roadside stop that changes the map of his heart.", _c(2), "#f1c40f", "trending", "Published", 4.9, "LGBTQ+", "Anxiety", 39, 0),
    ("No One Told Me My Rival Was My Fated Mate", "Rose Heart", "Rivals on the court. Mates by fate.", _c(3), "#3498db", "trending", "Published", 5.0, "LGBTQ+", "Love", 40, 0),
    ("The Wingman Who Fell First", "Aurora G", "He was only supposed to help—until he fell.", _c(4), "#1abc9c", "trending", "Published", 5.0, "LGBTQ+", "Mature", 41, 0),
    ("Want You, Hate You", "Written_By_Nate", "Hate was the mask. Want was the truth.", _c(5), "#e67e22", "trending", "Published", 4.5, "LGBTQ+", "Slowburnromance", 42, 0),
    ("STUCK with YOU", "Hitsy", "Stuck together. Falling apart. Falling in love.", _c(6), "#2c3e50", "trending", "Published", 5.0, "LGBTQ+", "Romance", 43, 0),
    # Werewolves & Shifters
    ("The Alpha's Exiled Mate", "Amal A. Usman", "Exiled from the pack, claimed by the one who banished her.", _c(7), "#5d4e37", "trending", "Published", 4.4, "Werewolves & Shifters", "Werewolf", 44, 0),
    ("Moonbound Hearts", "Luna Vale", "Every full moon pulls them closer to the truth.", _c(8), "#4a5568", "trending", "Published", 4.8, "Werewolves & Shifters", "Romance", 45, 0),
    ("The Whitefortis Alpha", "Pack Lore", "An alpha without mercy—until she arrived.", _c(9), "#2d3748", "trending", "Published", 4.8, "Werewolves & Shifters", "Alpha", 46, 0),
    ("Heart of the Moon", "Silver Fang", "The moon chose her. The pack disagreed.", _c(10), "#718096", "trending", "Published", 4.9, "Werewolves & Shifters", "Love", 47, 0),
    ("The Grizzly's Unintended Guest", "Northern Wilds", "A cabin in the woods. A shifter who doesn't share.", _c(11), "#553c2a", "trending", "Published", 5.0, "Werewolves & Shifters", "Bear", 48, 0),
    # Fantasy
    ("Goddess Tamer", "Ari Nova", "A reborn hero must tame a dangerous goddess.", _c(0), "#7F74C1", "recently_completed", "Completed", 4.9, "Fantasy", "Adventure", 49, 1),
    ("Avengard: The Fall of Senvia", "R. Den", "Two survivors chase a stolen voice across a drowned empire.", _c(1), "#6A8DB5", "recently_updated", "Published", 4.3, "Fantasy", "Romance", 50, 0),
    ("River (Revised version)", "Lola Grant", "Deeper character arcs in a historical fantasy world.", _c(2), "#8DB7C8", "recently_updated", "Published", 4.5, "Fantasy", "Drama", 51, 0),
    # Horror / Mystery
    ("Misery's Chosen", "I. Falon", "A shadowed figure with glowing eyes on a stormy night.", _c(3), "#4A4A62", "recently_completed", "Completed", 4.8, "Horror", "Mystery", 52, 1),
    ("Diary Of Nobody", "K. Haze", "Pages no one was meant to read.", _c(4), "#7D6A5A", "recently_updated", "Published", 4.1, "Poetry", "Drama", 53, 0),
]

INKITT_READING_LISTS = [
    ("Finished Reading", "PhoenixWerewolf", 13),
    ("Completed", "I'm_just_here", 10),
    ("Heart Breaking", "Jasmine N", 8),
    ("Mafia", "Anjola", 11),
    ("Favs", "abcya", 39),
    ("Vampire", "Gillian", 10),
    ("Update?", "abcya", 26),
]


def ensure_inkitt_catalog(execute_write, fetch_all, USE_SQLITE: bool) -> dict[str, Any]:
    """Insert missing Inkitt catalog books. Idempotent by title."""
    added = 0
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
            rows = fetch_all("SELECT id FROM books WHERE title=%s LIMIT 1", (title,))
            if rows:
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

    # Optional public reading-list-style categories as books already cover genres
    LOGGER.info("inkitt_seed: added %s books", added)
    return {"books_added": added, "catalog_size": len(INKITT_BOOKS)}
