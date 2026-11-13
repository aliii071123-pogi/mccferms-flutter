import 'package:flutter/material.dart';

import 'ferms_animations.dart';
import 'ferms_models.dart';
import 'ferms_repository.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, required this.repository, required this.user});

  final FermsRepository repository;
  final FermsUser user;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  int _rating = 0;
  bool _anonymous = false;
  bool _submitting = false;
  bool _loadingFeedback = false;
  String? _submitError;
  String? _feedbackError;
  FermsFeedbackPage? _feedbackPage;
  int _selectedTab = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitError = null);
    if (_rating == 0) {
      setState(() => _submitError = 'Choose a rating from 1 to 5 stars.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await widget.repository.submitFeedback(
        user: widget.user,
        rating: _rating,
        comment: _comment.text,
        anonymous: widget.user.normalizedRole == 'student' && _anonymous,
      );
      if (!mounted) return;
      _comment.clear();
      setState(() {
        _rating = 0;
        _anonymous = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you. Your feedback was submitted.'),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _submitError = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadFeedback({int? page}) async {
    if (!widget.user.canViewFeedback) return;
    final requestedPage = page ?? _feedbackPage?.currentPage ?? 1;
    setState(() {
      _loadingFeedback = true;
      _feedbackError = null;
    });
    try {
      final feedback = await widget.repository.feedback(
        user: widget.user,
        page: requestedPage,
      );
      if (mounted) setState(() => _feedbackPage = feedback);
    } catch (error) {
      if (mounted) setState(() => _feedbackError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingFeedback = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Feedback')),
    body: !widget.user.canSubmitFeedback
        ? const Center(
            child: Text('Feedback is not available for this account.'),
          )
        : Column(
            children: [
              if (widget.user.canViewFeedback)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Send feedback')),
                      ButtonSegment(value: 1, label: Text('Feedback inbox')),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (selection) {
                      final selected = selection.first;
                      setState(() => _selectedTab = selected);
                      if (selected == 1) _loadFeedback();
                    },
                  ),
                ),
              Expanded(
                child: _selectedTab == 1 && widget.user.canViewFeedback
                    ? _feedbackInbox()
                    : _feedbackForm(),
              ),
            ],
          ),
  );

  Widget _feedbackForm() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Share your experience',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        'Your feedback helps MCC improve facility and equipment services.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 24),
      const Text('Rating', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Semantics(
        label: _rating == 0 ? 'Choose a rating' : '$_rating out of 5 stars',
        child: Row(
          children: List.generate(
            5,
            (index) => IconButton(
              tooltip: '${index + 1} ${index == 0 ? 'star' : 'stars'}',
              onPressed: _submitting
                  ? null
                  : () => setState(() => _rating = index + 1),
              icon: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: const Color(0xFFE6A100),
                size: 32,
              ),
            ),
          ),
        ),
      ),
      Form(
        key: _formKey,
        child: TextFormField(
          controller: _comment,
          enabled: !_submitting,
          maxLength: 5000,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            alignLabelWithHint: true,
            labelText: 'Comment',
            hintText: 'Tell us what went well or what we can improve.',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a comment.' : null,
        ),
      ),
      if (widget.user.normalizedRole == 'student')
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Submit anonymously'),
          subtitle: const Text(
            'Your identity will not be attached to this feedback.',
          ),
          value: _anonymous,
          onChanged: _submitting
              ? null
              : (value) => setState(() => _anonymous = value),
        ),
      if (_submitError != null) ...[
        const SizedBox(height: 8),
        _ErrorNotice(_submitError!),
      ],
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const FermsLoadingIndicator(size: 20)
              : const Icon(Icons.send_outlined),
          label: Text(_submitting ? 'Submitting…' : 'Submit feedback'),
        ),
      ),
    ],
  );

  Widget _feedbackInbox() {
    if (!widget.user.canViewFeedback) {
      return const Center(
        child: Text('Only Admins and IT Administrators can view feedback.'),
      );
    }
    if (_loadingFeedback && _feedbackPage == null) {
      return const Center(child: FermsLoadingIndicator());
    }
    if (_feedbackError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ErrorNotice(_feedbackError!),
              TextButton.icon(
                onPressed: _loadFeedback,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final page = _feedbackPage;
    if (page == null || page.items.isEmpty) {
      return const Center(child: Text('No feedback has been submitted yet.'));
    }
    return Column(
      children: [
        if (_loadingFeedback)
          const Center(child: FermsLoadingIndicator(size: 28)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadFeedback(page: page.currentPage),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: page.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = page.items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${item.rating}/5 stars',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              item.isAnonymous
                                  ? 'Anonymous'
                                  : item.submitterName,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(item.comment),
                        if (item.createdAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(item.createdAt!),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('${page.total} responses'),
              const Spacer(),
              IconButton(
                tooltip: 'Previous page',
                onPressed: page.hasPreviousPage && !_loadingFeedback
                    ? () => _loadFeedback(page: page.currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page.currentPage} / ${page.lastPage}'),
              IconButton(
                tooltip: 'Next page',
                onPressed: page.hasNextPage && !_loadingFeedback
                    ? () => _loadFeedback(page: page.currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}
