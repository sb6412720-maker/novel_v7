part of 'discover_screen.dart';

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text, this.onReadMore});

  final String text;
  final VoidCallback? onReadMore;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim().isEmpty
        ? 'No description available yet.'
        : widget.text.trim();
    final needsToggle = text.length > 180;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: _expanded || !needsToggle ? null : 4,
          overflow: _expanded || !needsToggle
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.6,
            color: const Color(0xFF555555),
          ),
        ),
        if (needsToggle)
          TextButton(
            onPressed: () {
              if (widget.onReadMore != null) {
                widget.onReadMore!();
                return;
              }
              setState(() => _expanded = !_expanded);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: const TextStyle(
                color: AppTheme.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceAll('#', '');
  if (normalized.length < 6) return const Color(0xFFA1A1A1);
  return Color(int.parse('FF$normalized', radix: 16));
}

class _ExploreStoriesSection extends StatefulWidget {
  const _ExploreStoriesSection({
    required this.books,
    required this.topics,
    required this.apiService,
    required this.onOpenExplore,
  });

  final List<BookCardModel> books;
  final List<ExploreTopicModel> topics;
  final ApiService apiService;
  final VoidCallback onOpenExplore;

  @override
  State<_ExploreStoriesSection> createState() => _ExploreStoriesSectionState();
}

class _ExploreStoriesSectionState extends State<_ExploreStoriesSection> {
  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.42, initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<BookCardModel> get _validBooks =>
      widget.books.where((e) => e.id > 0 && e.title.trim().isNotEmpty).toList();

  BookCardModel get _activeBook {
    final books = _validBooks.isNotEmpty ? _validBooks : widget.books;
    return books[_activeIndex.clamp(0, books.length - 1)];
  }

  void _openBook(BookCardModel item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailScreen(
          apiService: widget.apiService,
          book: BookDetailModel(
            id: item.id,
            title: item.title,
            author: item.author,
            description: item.description,
            statusText: item.statusText,
            rating: item.rating,
            genre: item.primaryGenre,
            cta: item.cta,
            coverPath: item.coverPath,
          ),
        ),
      ),
    );
  }

  void _openSeeAll() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SectionBooksScreen(
          title: _activeBook.primaryGenre.isEmpty
              ? 'Stories'
              : _activeBook.primaryGenre,
          books: widget.books,
          apiService: widget.apiService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) return const SizedBox.shrink();
    final lead = _activeBook;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lead.primaryGenre.isEmpty ? 'Portal Fantasy' : lead.primaryGenre,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : null,
                    ),
              ),
            ),
            TextButton(
              onPressed: _openSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.brand,
                padding: const EdgeInsets.only(left: 0, right: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: _validBooks.length + 1,
            onPageChanged: (index) {
              if (index >= _validBooks.length) return;
              setState(() => _activeIndex = index);
            },
            itemBuilder: (context, index) {
              if (index >= _validBooks.length) {
                return const SizedBox.shrink();
              }
              final item = _validBooks[index];
              final isActive = index == _activeIndex;
              return AnimatedScale(
                scale: isActive ? 1.08 : 0.88,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: isActive ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 220),
                  child: GestureDetector(
                    onTap: () {
                      if (!isActive) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        _openBook(item);
                      }
                    },
                    child: Center(
                      child: _StoryCard(
                        book: item,
                        width: isActive ? 148 : 124,
                        apiService: widget.apiService,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Description / details follow the currently centered cover
        _ActiveStoryDetail(
          book: lead,
          apiService: widget.apiService,
          onRead: () => _openBook(lead),
        ),
        const SizedBox(height: 16),

      ],
    );
  }
}

class _DiscoverRailSection {
  const _DiscoverRailSection({required this.title, required this.books});

  final String title;
  final List<BookCardModel> books;
}

class _DynamicStoryRail extends StatefulWidget {
  const _DynamicStoryRail({required this.section, required this.apiService});

  final _DiscoverRailSection section;
  final ApiService apiService;

  @override
  State<_DynamicStoryRail> createState() => _DynamicStoryRailState();
}

class _DynamicStoryRailState extends State<_DynamicStoryRail> {
  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    // Match the first Discover slider format (no leading blank gap)
    _pageController = PageController(viewportFraction: 0.42, initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.section.books.isEmpty) {
      return const SizedBox.shrink();
    }

    final valid = widget.section.books
        .where((e) => e.id > 0 && e.title.trim().isNotEmpty)
        .toList();
    if (valid.isEmpty) return const SizedBox.shrink();
    final book = valid[_activeIndex.clamp(0, valid.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.section.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _SectionBooksScreen(
                      title: widget.section.title,
                      books: widget.section.books,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.brand,
                padding: const EdgeInsets.only(left: 0, right: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            // Same as first slider — no large leading blank space
            // Extra trailing page so the LAST book can fully slide into view
            padEnds: false,
            itemCount: valid.length + 1,
            onPageChanged: (index) {
              if (index >= valid.length) return;
              setState(() => _activeIndex = index);
            },
            itemBuilder: (context, index) {
              if (index >= valid.length) {
                return const SizedBox.shrink();
              }
              final item = valid[index];
              final isActive = index == _activeIndex;
              return AnimatedScale(
                scale: isActive ? 1.08 : 0.88,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: isActive ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 220),
                  child: GestureDetector(
                    onTap: () {
                      if (!isActive) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoryDetailScreen(
                              apiService: widget.apiService,
                              book: BookDetailModel(
                                id: item.id,
                                title: item.title,
                                author: item.author,
                                description: item.description,
                                statusText: item.statusText,
                                rating: item.rating,
                                genre: item.primaryGenre,
                                cta: item.cta,
                                coverPath: item.coverPath,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Center(
                      child: _StoryCard(
                        book: item,
                        width: isActive ? 148 : 124,
                        apiService: widget.apiService,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ActiveStoryDetail(
          book: book,
          apiService: widget.apiService,
          onRead: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoryDetailScreen(
                  apiService: widget.apiService,
                  book: BookDetailModel(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    description: book.description,
                    statusText: book.statusText,
                    rating: book.rating,
                    genre: book.primaryGenre,
                    cta: book.cta,
                    coverPath: book.coverPath,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}


class _ActiveStoryDetail extends StatelessWidget {
  const _ActiveStoryDetail({required this.book, this.onRead, this.apiService});

  final BookCardModel book;
  final VoidCallback? onRead;
  final ApiService? apiService;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _ExpandableDescription(
          text: book.description,
          onReadMore: () {
            if (onRead != null) {
              onRead!();
              return;
            }
            if (apiService == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StoryDetailScreen(
                  apiService: apiService!,
                  book: BookDetailModel(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    description: book.description,
                    statusText: book.statusText,
                    rating: book.rating,
                    genre: book.primaryGenre,
                    cta: book.cta,
                    coverPath: book.coverPath,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  book.statusText.isEmpty
                      ? 'Updated recently'
                      : book.statusText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${book.viewCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (book.rating > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  book.rating.round().clamp(0, 5),
                  (_) => const Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF3C623),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (book.isCompleted) ...[
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: AppTheme.brand,
              ),
              Text(
                'Completed',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.brand),
              ),
            ],
            _GenreTag(
              label: book.primaryGenre.isEmpty ? 'Novel' : book.primaryGenre,
            ),
            if (book.secondaryGenre.isNotEmpty)
              _GenreTag(label: book.secondaryGenre),
            ElevatedButton(
              onPressed: onRead,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                book.cta,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenreTag extends StatelessWidget {
  const _GenreTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }
}

class _StoryCard extends StatefulWidget {
  const _StoryCard({
    required this.book,
    required this.apiService,
    this.width = 140,
  });

  final BookCardModel book;
  final ApiService apiService;
  final double width;

  @override
  State<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<_StoryCard> {
  void _openDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryDetailScreen(
          apiService: widget.apiService,
          book: BookDetailModel(
            id: widget.book.id,
            title: widget.book.title,
            author: widget.book.author,
            description: widget.book.description,
            statusText: widget.book.statusText,
            rating: widget.book.rating,
            genre: widget.book.primaryGenre,
            cta: widget.book.cta,
            coverPath: widget.book.coverPath,
          ),
        ),
      ),
    );
  }

  Widget _coverImage({required double width, required double height}) {
    final seed = widget.book.id > 0
        ? widget.book.id
        : widget.book.title.hashCode;
    final asset = CoverAssets.assetForSeed(seed);
    final coverPath = widget.book.coverPath;
    if (coverPath.isNotEmpty) {
      final url = widget.apiService.resolveAssetUrl(coverPath);
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: width,
        height: height,
        cacheWidth: (width * 2).round().clamp(80, 600),
        cacheHeight: (height * 2).round().clamp(80, 800),
        errorBuilder: (_, _, _) => Image.asset(
          asset,
          fit: BoxFit.cover,
          width: width,
          height: height,
        ),
      );
    }
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(widget.book.accentHex);
    final compact = widget.width <= 140;

    if (compact) {
      return GestureDetector(
        onTap: _openDetail,
        child: SizedBox(
          width: widget.width,
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _coverImage(width: widget.width, height: 160),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 0.72,
                child: _coverImage(width: widget.width, height: widget.width / 0.72),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${widget.book.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AuthorsStrip extends StatefulWidget {
  const _AuthorsStrip({required this.books, required this.apiService});

  final List<BookCardModel> books;
  final ApiService apiService;

  @override
  State<_AuthorsStrip> createState() => _AuthorsStripState();
}

class _AuthorsStripState extends State<_AuthorsStrip> {
  Map<int, bool> _following = {};

  @override
  void initState() {
    super.initState();
    _loadFollowStates();
  }

  Future<void> _loadFollowStates() async {
    final ids = <int>[];
    final seenNames = <String>{};
    for (final book in widget.books) {
      final name = book.author.trim().isEmpty ? 'Unknown' : book.author;
      if (seenNames.contains(name)) continue;
      seenNames.add(name);
      final aid = book.authorUserId;
      if (aid != null) ids.add(aid);
      if (seenNames.length >= 8) break;
    }
    if (ids.isEmpty) return;
    final map = await widget.apiService.fetchAuthorsFollowing(ids);
    if (!mounted) return;
    setState(() => _following = map);
  }

  Future<void> _toggleFollowFor(int authorId) async {
    final currently = _following[authorId] ?? false;
    try {
      if (currently) {
        await widget.apiService.unfollowAuthor(authorId);
      } else {
        await widget.apiService.followAuthor(authorId);
      }
      if (!mounted) return;
      setState(() => _following[authorId] = !currently);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Prefer authors of Completed / Published / recently_updated stories
    // so a writer who finishes + saves a story appears under New Authors.
    final ranked = List<BookCardModel>.from(widget.books);
    ranked.sort((a, b) {
      int score(BookCardModel x) {
        final st = x.statusText.toLowerCase();
        var s = 0;
        if (st.contains('complete') || st.contains('publish')) s += 3;
        if (x.sectionName == 'recently_updated' ||
            x.sectionName == 'recently_completed') {
          s += 2;
        }
        if (x.authorUserId != null && x.authorUserId! > 0) s += 1;
        if (x.isCompleted) s += 2;
        return s;
      }

      return score(b).compareTo(score(a));
    });

    final byAuthor = <String, BookCardModel>{};
    for (final book in ranked) {
      final name = book.author.trim().isEmpty ? 'Unknown' : book.author;
      byAuthor.putIfAbsent(name, () => book);
      if (byAuthor.length >= 5) break;
    }

    final authors = byAuthor.entries.toList();
    if (authors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'New Authors',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : null,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _AuthorsSeeAllScreen(
                      books: widget.books,
                      apiService: widget.apiService,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.brand,
                padding: const EdgeInsets.only(left: 0, right: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Extra trailing space so last author is fully tappable
            padding: const EdgeInsets.only(right: 24),
            itemCount: authors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final author = authors[index].key;
              final book = authors[index].value;
              final letter = author.isNotEmpty ? author[0].toUpperCase() : 'A';
              final authorId = book.authorUserId;
              final rawPhoto = (book.authorPhotoUrl ?? '').trim();
              final photoUrl = rawPhoto.isNotEmpty
                  ? widget.apiService.resolveAssetUrl(rawPhoto)
                  : '';
              final isFollowing = authorId != null
                  ? (_following[authorId] ?? false)
                  : false;
              return Column(
                children: [
                  GestureDetector(
                    onTap: authorId != null
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProfileScreen(
                                  apiService: widget.apiService,
                                  viewingUserId: authorId,
                                  achievements: const [],
                                  profile: ProfileModel(
                                    id: authorId,
                                    displayName: author,
                                    username: author.toLowerCase().replaceAll(' ', ''),
                                    photoUrl: rawPhoto,
                                    coverUrl: '',
                                    following: 0,
                                    followers: 0,
                                    blocked: 0,
                                    chaptersRead: 0,
                                    socialKarma: 0,
                                    dayStreak: 0,
                                    readingLists: const [],
                                  ),
                                ),
                              ),
                            );
                          }
                        : null,
                    onLongPress: authorId != null
                        ? () => _toggleFollowFor(authorId)
                        : null,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2A3344)
                              : const Color(0xFFE8EEF9),
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          onBackgroundImageError: photoUrl.isNotEmpty
                              ? (_, _) {}
                              : null,
                          child: photoUrl.isEmpty
                              ? Text(
                                  letter,
                                  style: const TextStyle(
                                    color: AppTheme.brand,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        if (authorId != null)
                          Positioned(
                            right: -4,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isFollowing
                                    ? Colors.white
                                    : Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  color: isFollowing
                                      ? AppTheme.brand
                                      : Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 9,
                                color: AppTheme.muted,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GenrePillRow extends StatelessWidget {
  const _GenrePillRow({
    required this.topics,
    required this.books,
    required this.apiService,
  }) : onOpenExplore = null;

  final List<ExploreTopicModel> topics;
  final List<BookCardModel> books;
  final ApiService apiService;
  final VoidCallback? onOpenExplore;

  @override
  Widget build(BuildContext context) {
    final genres = <String>{};
    for (final b in books) {
      if (b.primaryGenre.isNotEmpty) genres.add(b.primaryGenre);
      if (genres.length >= 8) break;
    }
    final items = genres.toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + (onOpenExplore != null ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (onOpenExplore != null && index == items.length) {
            return ActionChip(
              label: Text(
                'Explore more',
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: isDark ? const Color(0xFF2A3344) : const Color(0xFFE8EEF9),
              onPressed: onOpenExplore,
            );
          }
          final label = items[index];
          return ActionChip(
            label: Text(
              label,
              style: TextStyle(color: isDark ? Colors.white : null),
            ),
            onPressed: () async {
              // Only related hashtag/genre books — never jump to Explore
              var tagged = await apiService.fetchBooksByTag(label);
              if (tagged.isEmpty) {
                // Client-side filter from current discover books
                tagged = books
                    .where((b) {
                      final g = label.toLowerCase();
                      return b.primaryGenre.toLowerCase().contains(g) ||
                          b.secondaryGenre.toLowerCase().contains(g);
                    })
                    .map((b) => {
                          'id': b.id,
                          'title': b.title,
                          'author': b.author,
                          'description': b.description,
                          'status_text': b.statusText,
                          'rating': b.rating,
                          'genre': b.primaryGenre,
                          'primary_genre': b.primaryGenre,
                          'cover_path': b.coverPath,
                          'cta_label': b.cta,
                          'author_user_id': b.authorUserId,
                        })
                    .toList();
              }
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _GenreBooksScreen(
                    genre: label,
                    books: tagged,
                    apiService: apiService,
                    onExploreMore: onOpenExplore,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}



/// Horizontal "Browse genres" carousel (video-style genre cards).


/// Wattpad-style Continue reading strip (always visible).
class _ContinueReadingSection extends StatefulWidget {
  const _ContinueReadingSection({
    required this.entries,
    required this.apiService,
    this.onBrowse,
  });

  final List<LibraryEntryModel> entries;
  final ApiService apiService;
  final VoidCallback? onBrowse;

  @override
  State<_ContinueReadingSection> createState() =>
      _ContinueReadingSectionState();
}

class _ContinueReadingSectionState extends State<_ContinueReadingSection> {
  List<LibraryEntryModel> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _items = _filterOngoing(widget.entries);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _ContinueReadingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      _items = _filterOngoing(widget.entries);
    }
  }

  List<LibraryEntryModel> _filterOngoing(List<LibraryEntryModel> list) {
    return list.where((e) {
      final st = e.readingStatus.toLowerCase().trim();
      if (st.contains('complete') || st.contains('finished')) return false;
      // Keep if any progress or just started
      return e.book.id > 0;
    }).toList();
  }

  Future<void> _refresh() async {
    final merged = <int, LibraryEntryModel>{};

    // 1) Bootstrap seed
    for (final e in widget.entries) {
      if (e.book.id > 0) merged[e.book.id] = e;
    }

    // 2) Local cache (always works offline / even if API 401)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('continue_reading_v1') ?? '{}';
      final map = Map<String, dynamic>.from(
        (jsonDecode(raw) as Map?) ?? const {},
      );
      for (final entry in map.values) {
        if (entry is! Map) continue;
        final m = Map<String, dynamic>.from(entry);
        final model = LibraryEntryModel.fromMap(m);
        if (model.book.id > 0) {
          merged[model.book.id] = model;
        }
      }
    } catch (_) {}

    // 3) Live API
    try {
      final remote = await widget.apiService.fetchLibraryEntries();
      for (final row in remote) {
        final model = LibraryEntryModel.fromMap(row);
        if (model.book.id > 0) {
          merged[model.book.id] = model;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _items = _filterOngoing(merged.values.toList());
      _loading = false;
    });
  }

  Widget _continueCover(BookCardModel b, {double w = 110, double h = 150}) {
    final asset = CoverAssets.assetForSeed(b.id > 0 ? b.id : b.title.hashCode);
    if (b.coverPath.isNotEmpty) {
      return Image.network(
        widget.apiService.resolveAssetUrl(b.coverPath),
        fit: BoxFit.cover,
        width: w,
        height: h,
        cacheWidth: (w * 2).round(),
        cacheHeight: (h * 2).round(),
        errorBuilder: (_, _, _) =>
            Image.asset(asset, fit: BoxFit.cover, width: w, height: h),
      );
    }
    return Image.asset(asset, fit: BoxFit.cover, width: w, height: h);
  }

  Future<void> _openResume(
    BuildContext context,
    LibraryEntryModel entry,
  ) async {
    final b = entry.book;
    List<Map<String, dynamic>> chapters = const [];
    try {
      chapters = await widget.apiService.fetchStoryChapters(b.id);
    } catch (_) {}
    if (!context.mounted) return;

    int chapterIndex = 0;
    int chapterNumber =
        entry.lastChapterNumber > 0 ? entry.lastChapterNumber : 1;
    String chapterTitle = 'Chapter $chapterNumber';
    String chapterContent = '';

    if (chapters.isNotEmpty) {
      final idx = chapters.indexWhere(
        (c) => (c['chapter_number'] as num?)?.toInt() == chapterNumber,
      );
      chapterIndex = idx >= 0 ? idx : 0;
      final ch = chapters[chapterIndex];
      chapterNumber =
          (ch['chapter_number'] as num?)?.toInt() ?? chapterNumber;
      chapterTitle = (ch['title'] ?? chapterTitle).toString();
      chapterContent = (ch['content'] ?? '').toString();
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterReaderScreen(
          apiService: widget.apiService,
          title: b.title,
          author: b.author,
          coverPath: b.coverPath,
          chapterNumber: chapterNumber,
          chapterTitle: chapterTitle,
          chapterContent: chapterContent,
          bookId: b.id,
          chapters: chapters,
          initialChapterIndex: chapterIndex,
          initialParagraphIndex: entry.lastParagraphIndex,
          authorUserId: b.authorUserId,
        ),
      ),
    );
    // Refresh list after returning from reader
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final books = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Continue reading',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : null,
                    ),
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: _refresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final entry in books)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => _openResume(context, entry),
                    child: SizedBox(
                      width: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 110,
                              height: 150,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _continueCover(entry.book),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      height: 4,
                                      color: Colors.black.withValues(alpha: 0.35),
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: entry.progressFraction
                                            .clamp(0.05, 1.0),
                                        child: Container(
                                          color: const Color(0xFFFF5722),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.updatedText.isNotEmpty
                                ? entry.updatedText
                                : 'Ch. ${entry.lastChapterNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF4F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        books.isEmpty
                            ? "Stories you're reading will appear here"
                            : 'Find more stories',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: widget.onBrowse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Browse stories',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}





class _BrowseGenresSection extends StatelessWidget {
  const _BrowseGenresSection({
    required this.books,
    required this.topics,
    required this.apiService,
    this.onOpenExplore,
  });

  final List<BookCardModel> books;
  final List<ExploreTopicModel> topics;
  final ApiService apiService;
  final VoidCallback? onOpenExplore;

  static const _palette = <Color>[
    Color(0xFFE14FA0),
    Color(0xFF8B5CF6),
    Color(0xFF00A88E),
    Color(0xFFF0B357),
    Color(0xFF5B9BD5),
    Color(0xFFE85D4C),
    Color(0xFF9B59B6),
    Color(0xFF2ECC71),
  ];

  @override
  Widget build(BuildContext context) {
    final genres = <String>[];
    final seen = <String>{};
    for (final b in books) {
      for (final g in [b.primaryGenre, b.secondaryGenre]) {
        final s = g.trim();
        if (s.isEmpty) continue;
        final key = s.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        genres.add(s);
        if (genres.length >= 12) break;
      }
      if (genres.length >= 12) break;
    }
    for (final t in topics) {
      final s = t.name.trim();
      if (s.isEmpty) continue;
      final key = s.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      genres.add(s);
      if (genres.length >= 12) break;
    }
    if (genres.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Browse genres',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : null,
                    ),
              ),
            ),
            if (onOpenExplore != null)
              TextButton(
                onPressed: onOpenExplore,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.brand,
                  padding: const EdgeInsets.only(left: 0, right: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: genres.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final label = genres[index];
              final color = _palette[index % _palette.length];
              // Prefer a cover from a book in this genre for Inkitt-style cards
              String coverPath = '';
              for (final b in books) {
                if (b.primaryGenre.toLowerCase().contains(label.toLowerCase()) ||
                    b.secondaryGenre.toLowerCase().contains(label.toLowerCase())) {
                  if (b.coverPath.isNotEmpty) {
                    coverPath = b.coverPath;
                    break;
                  }
                }
              }
              return GestureDetector(
                onTap: () async {
                  // Prefer API genre search, then local books filter
                  var tagged = <Map<String, dynamic>>[];
                  try {
                    tagged = await apiService.searchStories(
                      query: '',
                      genre: label,
                    );
                  } catch (_) {}
                  if (tagged.isEmpty) {
                    try {
                      tagged = await apiService.fetchBooksByTag(label);
                    } catch (_) {}
                  }
                  if (tagged.isEmpty) {
                    tagged = books
                        .where((b) {
                          final g = label.toLowerCase();
                          return b.primaryGenre.toLowerCase().contains(g) ||
                              b.secondaryGenre.toLowerCase().contains(g);
                        })
                        .map((b) => {
                              'id': b.id,
                              'title': b.title,
                              'author': b.author,
                              'description': b.description,
                              'status_text': b.statusText,
                              'rating': b.rating,
                              'genre': b.primaryGenre,
                              'primary_genre': b.primaryGenre,
                              'cover_path': b.coverPath,
                              'cta_label': b.cta,
                              'author_user_id': b.authorUserId,
                            })
                        .toList();
                  }
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _GenreBooksScreen(
                        genre: label,
                        books: tagged,
                        apiService: apiService,
                        onExploreMore: onOpenExplore,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverPath.isNotEmpty)
                        Image.network(
                          apiService.resolveAssetUrl(coverPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: color),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [color, color.withValues(alpha: 0.7)],
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.2,
                              shadows: [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.labels, required this.tabController});

  final List<String> labels;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final isSelected = tabController.index == index;
          return GestureDetector(
            onTap: () => tabController.animateTo(index),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected
                        ? AppTheme.brand
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.muted),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  width: isSelected
                      ? math.max(labels[index].length * 11.0, 60)
                      : 0,
                  color: isSelected ? AppTheme.brand : Colors.transparent,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _TabBarDelegate({required this.child});

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}


class _SectionBooksScreen extends StatelessWidget {
  const _SectionBooksScreen({
    required this.title,
    required this.books,
    required this.apiService,
  });

  final String title;
  final List<BookCardModel> books;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : null,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(color: isDark ? Colors.white : null),
        ),
        backgroundColor: isDark ? const Color(0xFF121212) : null,
        iconTheme: IconThemeData(color: isDark ? Colors.white : null),
      ),
      body: books.isEmpty
          ? Center(
              child: Text(
                'No stories in this section yet',
                style: TextStyle(color: isDark ? Colors.white70 : null),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = books[index];
                final cover = item.coverPath;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFE8E8E8),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: apiService,
                          book: BookDetailModel(
                            id: item.id,
                            title: item.title,
                            author: item.author,
                            description: item.description,
                            statusText: item.statusText,
                            rating: item.rating,
                            genre: item.primaryGenre,
                            cta: item.cta,
                            coverPath: item.coverPath,
                          ),
                        ),
                      ),
                    );
                  },
                  leading: SizedBox(
                    width: 40,
                    height: 56,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: cover.isNotEmpty
                          ? Image.network(
                              apiService.resolveAssetUrl(cover),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Image.asset(
                                CoverAssets.assetForSeed(item.id),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              CoverAssets.assetForSeed(item.id),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(color: isDark ? Colors.white : null),
                  ),
                  subtitle: Text(
                    item.author,
                    style: TextStyle(color: isDark ? Colors.white70 : null),
                  ),
                );
              },
            ),
    );
  }
}

class _GenreBooksScreen extends StatefulWidget {
  const _GenreBooksScreen({
    required this.genre,
    required this.books,
    required this.apiService,
    this.onExploreMore,
  });

  final String genre;
  final List<Map<String, dynamic>> books;
  final ApiService apiService;
  final VoidCallback? onExploreMore;

  @override
  State<_GenreBooksScreen> createState() => _GenreBooksScreenState();
}

class _GenreBooksScreenState extends State<_GenreBooksScreen> {
  late List<Map<String, dynamic>> _books;
  bool _loading = false;
  String _sort = 'Popular';
  String _period = 'All time';

  static const _sortOptions = [
    'Popular',
    'Completed',
    'Unexplored',
    'Recently Updated',
  ];
  static const _periodOptions = ['All time', 'Last 30 days'];

  @override
  void initState() {
    super.initState();
    _books = List<Map<String, dynamic>>.from(widget.books);
    _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    setState(() => _loading = true);
    try {
      final remote = await widget.apiService.searchStories(
        query: '',
        genre: widget.genre,
        minRating: 0,
      );
      if (!mounted) return;
      if (remote.isNotEmpty) {
        setState(() {
          _books = remote;
          _applyFiltersLocal();
          _loading = false;
        });
      } else {
        setState(() {
          _applyFiltersLocal();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _applyFiltersLocal();
          _loading = false;
        });
      }
    }
  }

  void _applyFiltersLocal() {
    var list = List<Map<String, dynamic>>.from(
      _books.isEmpty && widget.books.isNotEmpty ? widget.books : _books,
    );
    // Filter by genre field match
    final g = widget.genre.toLowerCase();
    list = list.where((b) {
      final pg = (b['primary_genre'] ?? b['genre'] ?? '').toString().toLowerCase();
      final sg = (b['secondary_genre'] ?? '').toString().toLowerCase();
      return pg.contains(g) || sg.contains(g) || g.isEmpty;
    }).toList();

    if (_sort == 'Completed') {
      list = list.where((b) {
        final st = (b['status_text'] ?? '').toString().toLowerCase();
        final done = b['is_completed'] == true || b['is_completed'] == 1;
        return done || st.contains('complete') || st.contains('published');
      }).toList();
    } else if (_sort == 'Recently Updated') {
      list.sort((a, b) {
        final ai = (a['id'] as num?)?.toInt() ?? 0;
        final bi = (b['id'] as num?)?.toInt() ?? 0;
        return bi.compareTo(ai);
      });
    } else if (_sort == 'Popular') {
      list.sort((a, b) {
        final ar = (a['rating'] as num?)?.toDouble() ?? 0;
        final br = (b['rating'] as num?)?.toDouble() ?? 0;
        return br.compareTo(ar);
      });
    }
    _books = list;
  }

  BookDetailModel _toBook(Map<String, dynamic> m) {
    return BookDetailModel.fromMap({
      'id': m['id'],
      'title': m['title'] ?? '',
      'author': m['author'] ?? '',
      'description': m['description'] ?? '',
      'cover_path': m['cover_path'] ?? '',
      'genre': m['genre'] ?? m['primary_genre'] ?? '',
      'primary_genre': m['primary_genre'] ?? m['genre'] ?? '',
      'secondary_genre': m['secondary_genre'] ?? '',
      'status_text': m['status_text'] ?? '',
      'rating': m['rating'] ?? 0,
      'tags': m['tags'] ?? [],
      'author_user_id': m['author_user_id'] ?? m['user_id'],
      'user_id': m['user_id'] ?? m['author_user_id'],
      'likes_count': m['likes_count'] ?? 0,
      'is_completed': m['is_completed'] ?? false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final genre = widget.genre;
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) {
          return [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: const Color(0xFF1A1A2E),
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  genre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Soft gradient hero (Inkitt-style)
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF2D4A6F),
                            Color(0xFF1A1A2E),
                          ],
                        ),
                      ),
                    ),
                    // Decorative book covers from list if any
                    if (_books.isNotEmpty)
                      Opacity(
                        opacity: 0.35,
                        child: Image.network(
                          widget.apiService.resolveAssetUrl(
                            (_books.first['cover_path'] ?? '').toString(),
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    _FilterChipBtn(
                      label: _sort,
                      options: _sortOptions,
                      onSelected: (v) {
                        setState(() {
                          _sort = v;
                          _applyFiltersLocal();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChipBtn(
                      label: _period,
                      options: _periodOptions,
                      onSelected: (v) {
                        setState(() {
                          _period = v;
                          _applyFiltersLocal();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _books.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No stories in this genre yet'),
                        if (widget.onExploreMore != null)
                          TextButton(
                            onPressed: widget.onExploreMore,
                            child: const Text('Explore more'),
                          ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: _books.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final item = _books[index];
                      final title = (item['title'] ?? 'Untitled').toString();
                      final author = (item['author'] ?? '').toString();
                      final desc = (item['description'] ?? '').toString();
                      final cover = (item['cover_path'] ?? '').toString();
                      final rating =
                          (item['rating'] as num?)?.toDouble() ?? 0.0;
                      final genreLabel = (item['primary_genre'] ??
                              item['genre'] ??
                              widget.genre)
                          .toString();
                      final status =
                          (item['status_text'] ?? '').toString();
                      final completed = item['is_completed'] == true ||
                          item['is_completed'] == 1 ||
                          status.toLowerCase().contains('complete') ||
                          status.toLowerCase().contains('published');
                      final chapters =
                          (item['chapters_count'] as num?)?.toInt() ??
                              (item['chapter_count'] as num?)?.toInt();

                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StoryDetailScreen(
                                book: _toBook(item),
                                apiService: widget.apiService,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 78,
                                height: 110,
                                child: cover.isNotEmpty
                                    ? Image.network(
                                        widget.apiService
                                            .resolveAssetUrl(cover),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color: const Color(0xFFE8E8E8),
                                          child: const Icon(
                                              Icons.menu_book_rounded),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFE8E8E8),
                                        child: const Icon(
                                            Icons.menu_book_rounded),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.bookmark_border_rounded,
                                        size: 20,
                                        color: Colors.black45,
                                      ),
                                    ],
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF666666),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 16,
                                          color: Color(0xFFFFC107)),
                                      const SizedBox(width: 2),
                                      Text(
                                        rating > 0
                                            ? rating.toStringAsFixed(1)
                                            : '—',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                const Color(0xFFDDDDDD),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          genreLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF555555),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (completed) ...[
                                        const Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: Color(0xFF00A88E),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Completed',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF00A88E),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                      if (chapters != null) ...[
                                        Text(
                                          completed
                                              ? ' · $chapters Chapters'
                                              : '$chapters Chapters',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (author.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'By $author',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF999999),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _FilterChipBtn extends StatelessWidget {
  const _FilterChipBtn({
    required this.label,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (ctx) => options
          .map(
            (o) => PopupMenuItem<String>(
              value: o,
              child: Text(o),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}




class _AuthorsSeeAllScreen extends StatelessWidget {
  const _AuthorsSeeAllScreen({required this.books, required this.apiService});
  final List<BookCardModel> books;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    final ranked = List<BookCardModel>.from(
      books.where((b) => b.author.trim().isNotEmpty),
    );
    ranked.sort((a, b) {
      int score(BookCardModel x) {
        var s = 0;
        if (x.authorUserId != null && x.authorUserId! > 0) s += 1;
        if (x.isCompleted) s += 2;
        return s;
      }
      return score(b).compareTo(score(a));
    });
    final byAuthor = <String, BookCardModel>{};
    for (final book in ranked) {
      final name = book.author.trim().isEmpty ? 'Unknown' : book.author;
      byAuthor.putIfAbsent(name, () => book);
    }
    final authors = byAuthor.entries.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Authors')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: authors.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final author = authors[index].key;
          final book = authors[index].value;
          final authorId = book.authorUserId;
          return ListTile(
            leading: CircleAvatar(
              child: Text(author.isNotEmpty ? author[0].toUpperCase() : 'A'),
            ),
            title: Text(author),
            subtitle: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: authorId == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileScreen(
                          apiService: apiService,
                          viewingUserId: authorId,
                          achievements: const [],
                          profile: ProfileModel(
                            id: authorId,
                            displayName: author,
                            username: author.toLowerCase().replaceAll(' ', ''),
                            photoUrl: book.authorPhotoUrl ?? '',
                            coverUrl: '',
                            following: 0,
                            followers: 0,
                            blocked: 0,
                            chaptersRead: 0,
                            socialKarma: 0,
                            dayStreak: 0,
                            readingLists: const [],
                          ),
                        ),
                      ),
                    );
                  },
          );
        },
      ),
    );
  }
}
