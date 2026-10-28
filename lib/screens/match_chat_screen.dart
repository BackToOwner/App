import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../controllers/chat_unread_controller.dart';
import '../models/app_user.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/auth/auth_service_interface.dart';

class MatchChatScreen extends StatefulWidget {
  final String matchId;

  const MatchChatScreen({super.key, required this.matchId});

  @override
  State<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends State<MatchChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  Timer? _refreshTimer;
  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;
  bool _confirmationLoading = false;
  bool _confirmingReturn = false;
  bool _confirmationEligible = false;
  bool _confirmationChecked = false;
  Map<String, dynamic>? _returnConfirmation;
  String? _confirmationError;
  String? _error;

  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _currentUser = context.read<IAuthService>().currentUser;
      _loadMessages();
      _loadReturnConfirmation();

      // Refresh periodically so messages from the other reporter appear.
      _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted && !_sending && !_refreshing) {
          _loadMessages(silent: true);
        }
        if (mounted) {
          _loadReturnConfirmation(silent: true);
        }
      });
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_refreshing || !mounted) return;

    _refreshing = true;

    if (!silent && _messages.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await context
          .read<ApiClient>()
          .get<Map<String, dynamic>>(
            '/chat/matches/${widget.matchId}/messages',
            query: {'pageSize': 100},
          );

      final rawMessages = response['messages'] as List? ?? [];

      final loaded = rawMessages.whereType<Map<String, dynamic>>().toList();

      if (!mounted) return;

      final hadNewMessages =
          loaded.length != _messages.length ||
          (loaded.isNotEmpty &&
              _messages.isNotEmpty &&
              loaded.last['id'] != _messages.last['id']);

      setState(() {
        _messages = loaded;
        _error = null;
        _loading = false;
      });

      // Mark only this approved conversation as read after messages load successfully.
      // A read-marker failure must not make successfully loaded messages appear to fail.
      try {
        await context.read<ApiClient>().post<Map<String, dynamic>>(
          '/chat/matches/${widget.matchId}/read',
        );
        if (mounted) {
          await context.read<ChatUnreadController>().load();
        }
      } catch (_) {
        // The next refresh can retry the read marker.
      }

      if (hadNewMessages || !silent) {
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load messages. Please try again.';
          _loading = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadReturnConfirmation({bool silent = false}) async {
    if (_confirmationLoading || !mounted) return;

    if (!silent) {
      setState(() {
        _confirmationLoading = true;
        _confirmationError = null;
      });
    } else {
      _confirmationLoading = true;
    }

    try {
      final response = await context
          .read<ApiClient>()
          .get<Map<String, dynamic>>(
            '/chat/matches/${widget.matchId}/return-confirmation',
          );

      final raw = response['data'];
      final data = raw is Map ? Map<String, dynamic>.from(raw) : response;

      if (!mounted) return;

      setState(() {
        _returnConfirmation = data;
        _confirmationEligible = true;
        _confirmationChecked = true;
        _confirmationError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      final message = e.message.toLowerCase();
      final waitingForReturn =
          message.contains('marked returned') ||
          message.contains('must be returned') ||
          message.contains('before confirmation');

      setState(() {
        _confirmationEligible = false;
        _confirmationChecked = true;
        _confirmationError = waitingForReturn ? null : e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _confirmationChecked = true;
        _confirmationEligible = false;
        _confirmationError = 'Could not load return-confirmation progress.';
      });
    } finally {
      if (mounted) {
        setState(() => _confirmationLoading = false);
      } else {
        _confirmationLoading = false;
      }
    }
  }

  Future<void> _confirmReturn() async {
    if (_confirmingReturn ||
        !_confirmationEligible ||
        _returnConfirmation?['confirmedByMe'] == true) {
      return;
    }

    setState(() {
      _confirmingReturn = true;
      _confirmationError = null;
    });

    try {
      final response = await context
          .read<ApiClient>()
          .post<Map<String, dynamic>>(
            '/chat/matches/${widget.matchId}/return-confirmation',
          );

      final raw = response['data'];
      final data = raw is Map ? Map<String, dynamic>.from(raw) : response;

      if (!mounted) return;

      setState(() {
        _returnConfirmation = data;
        _confirmationEligible = true;
        _confirmationChecked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your return confirmation was saved.')),
      );

      await _loadReturnConfirmation();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _confirmationError = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _confirmationError =
              'Could not save your confirmation. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _confirmingReturn = false);
    }
  }

  Widget _buildReturnConfirmationCard() {
    final data = _returnConfirmation;
    final confirmedCount = (data?['confirmedCount'] as num?)?.toInt() ?? 0;
    final totalParticipants =
        (data?['totalParticipants'] as num?)?.toInt() ?? 2;
    final confirmedByMe = data?['confirmedByMe'] == true;
    final canClose = data?['canClose'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Return confirmation',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_confirmationEligible)
                Text(
                  '$confirmedCount/$totalParticipants',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_confirmationLoading && !_confirmationChecked)
            const LinearProgressIndicator()
          else if (_confirmationError != null) ...[
            Text(
              _confirmationError!,
              style: const TextStyle(fontSize: 12, color: AppColors.errorRed),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _confirmationLoading
                    ? null
                    : () => _loadReturnConfirmation(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ),
          ] else if (!_confirmationEligible) ...[
            const Text(
              'Confirmation becomes available after an admin marks both matched reports as returned.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _confirmationLoading
                    ? null
                    : () => _loadReturnConfirmation(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Check status'),
              ),
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: totalParticipants > 0
                    ? (confirmedCount / totalParticipants).clamp(0.0, 1.0)
                    : 0,
                minHeight: 6,
                backgroundColor: AppColors.borderColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canClose
                  ? 'Both participants have confirmed. An admin can now close the case.'
                  : confirmedByMe
                  ? 'You have confirmed the return. Waiting for the other participant.'
                  : 'If the item has been returned, confirm below. Both participants must confirm before the admin can close the case.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            if (!canClose && !confirmedByMe) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmingReturn ? null : _confirmReturn,
                  icon: _confirmingReturn
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _confirmingReturn
                        ? 'Saving confirmation...'
                        : 'Confirm item returned',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            if (confirmedByMe)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: Colors.green,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Your confirmation is recorded',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();

    if (body.isEmpty || _sending) return;

    if (body.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Messages cannot exceed 5000 characters.'),
        ),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await context.read<ApiClient>().post<Map<String, dynamic>>(
        '/chat/matches/${widget.matchId}/messages',
        data: {'body': body},
      );

      if (!mounted) return;

      _messageController.clear();
      await _loadMessages();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send your message. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkNavy,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match chat',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              'Private conversation between reporters',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: () => _loadMessages(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildReturnConfirmationCard(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && _error != null
                ? _buildError()
                : _messages.isEmpty
                ? RefreshIndicator(
                    onRefresh: _loadMessages,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 150),
                        Icon(
                          Icons.forum_outlined,
                          size: 52,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Start the conversation',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Coordinate privately about returning the item.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine =
                          userId != null &&
                          message['sender_id']?.toString() == userId;

                      return _buildMessage(message, isMine);
                    },
                  ),
          ),
          if (_error != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Refresh issue: $_error',
                style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 5000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.fieldBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: IconButton.filled(
                      onPressed: _sending ? null : _sendMessage,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message, bool isMine) {
    final body = message['body']?.toString() ?? '';
    final createdAt = DateTime.tryParse(
      message['created_at']?.toString() ?? '',
    )?.toLocal();

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                body,
                style: TextStyle(
                  color: isMine ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 5),
              Text(
                '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 44,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Could not load this conversation.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _loadMessages(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
