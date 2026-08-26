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
class _ContinueReadingSection extends StatelessWidget {
  const _ContinueReadingSection({
    required this.entries,
    required this.apiService,
    this.onBrowse,
  });

  final List<LibraryEntryModel> entries;
  final ApiService apiService;
  final VoidCallback? onBrowse;

  Widget _continueCover(BookCardModel b, {double w = 110, double h = 160}) {
    final asset = CoverAssets.assetForSeed(b.id > 0 ? b.id : b.title.hashCode);
    if (b.coverPath.isNotEmpty) {
      return Image.network(
        apiService.resolveAssetUrl(b.coverPath),
        fit: BoxFit.cover,
        width: w,
        height: h,
        cacheWidth: (w * 2).round(),
        cacheHeight: (h * 2).round(),
        errorBuilder: (_, _, _) => Image.asset(asset, fit: BoxFit.cover, width: w, height: h),
      );
    }
    return Image.asset(asset, fit: BoxFit.cover, width: w, height: h);
  }

  @override
  Widget build(BuildContext context) {
    final books = entries
        .map((e) => e.book)
        .where((b) => b.id > 0)
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Centered section on Discover page
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Continue reading',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: isDark ? Colors.white : null,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: Center(
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: [
                for (final b in books.take(8))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StoryDetailScreen(
                              apiService: apiService,
                              book: BookDetailModel(
                                id: b.id,
                                title: b.title,
                                author: b.author,
                                description: b.description,
                                statusText: b.statusText,
                                rating: b.rating,
                                genre: b.primaryGenre,
                                cta: b.cta,
                                coverPath: b.coverPath,
                                authorUserId: b.authorUserId,
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 110,
                          height: 160,
                          child: _continueCover(b),
                        ),
                      ),
                    ),
                  ),
              // Empty-state / Browse card
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 150,
                  height: 160,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F6),
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
                        onPressed: onBrowse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Browse stories', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
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
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: genres.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final label = genres[index];
              final color = _palette[index % _palette.length];
              return GestureDetector(
                onTap: () async {
                  var tagged = await apiService.fetchBooksByTag(label);
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
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.85),
                        color.withValues(alpha: 0.55),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_stories_rounded, color: Colors.white.withValues(alpha: 0.95), size: 22),
                      const Spacer(),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.2,
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

class _GenreBooksScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = genre.startsWith('#') ? genre : '#$genre';
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : null,
      appBar: AppBar(
        title: Text(label, style: TextStyle(color: isDark ? Colors.white : null)),
        backgroundColor: isDark ? const Color(0xFF121212) : null,
        iconTheme: IconThemeData(color: isDark ? Colors.white : null),
        actions: [
          if (onExploreMore != null)
            TextButton(
              onPressed: onExploreMore,
              child: const Text('Explore more'),
            ),
        ],
      ),
      body: books.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No stories for this tag yet',
                    style: TextStyle(color: isDark ? Colors.white70 : null),
                  ),
                  if (onExploreMore != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onExploreMore,
                      child: const Text('Explore more stories'),
                    ),
                  ],
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: books.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = books[index];
                final cover = (item['cover_path'] ?? '').toString();
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E8)),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoryDetailScreen(
                          apiService: apiService,
                          book: BookDetailModel.fromMap(item),
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
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                CoverAssets.assetForSeed(
                                  (item['id'] as num?)?.toInt() ??
                                      (item['title']?.toString() ?? '').hashCode,
                                ),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              CoverAssets.assetForSeed(
                                (item['id'] as num?)?.toInt() ??
                                    (item['title']?.toString() ?? '').hashCode,
                              ),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  title: Text(item['title']?.toString() ?? ''),
                  subtitle: Text(item['author']?.toString() ?? ''),
                );
              },
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
