import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/whatsapp_chat_provider.dart';

/// Full-screen donor support chat (WhatsApp-style, synced with Django).
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WhatsAppChatProvider>().initChat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openExternalWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/${ApiConstants.whatsappBusinessNumber}?text='
      '${Uri.encodeComponent('Hello Blood450, I need support')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Consumer<WhatsAppChatProvider>(
          builder: (_, p, __) => Text(p.chatTitle),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open WhatsApp app',
            onPressed: _openExternalWhatsApp,
          ),
        ],
      ),
      body: Consumer<WhatsAppChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(provider.error!, textAlign: TextAlign.center),
              ),
            );
          }
          return Column(
            children: [
              Material(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'To contact support: open WhatsApp and message our number '
                        '+1 (555) 656-5019. Your phone must be added in Meta test recipients.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _openExternalWhatsApp,
                        icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                        label: const Text('Open WhatsApp to message Blood450'),
                      ),
                    ],
                  ),
                ),
              ),
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    provider.error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final m = provider.messages[index] as Map<String, dynamic>;
                    final inbound = m['direction'] == 'inbound';
                    return Align(
                      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: inbound ? Colors.white : const Color(0xFFDCF8C6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['body']?.toString() ?? ''),
                            const SizedBox(height: 4),
                            Text(
                              '${m['status'] ?? ''}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Material(
                color: const Color(0xFFF0F2F5),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Type a message…',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: const Color(0xFF25D366),
                          onPressed: () async {
                            final ok = await provider.send(_controller.text);
                            if (ok) _controller.clear();
                            if (!context.mounted) return;
                            if (!ok) {
                              final msg = provider.error ??
                                  'Failed to send. Use "Open WhatsApp" above or add your '
                                  'number in Meta test recipients.';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  backgroundColor: AppColors.error,
                                  duration: const Duration(seconds: 6),
                                ),
                              );
                            }
                          },
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
