/// Pending navigation target when the user opens a direct-message push notification.
class DmNavigationIntent {
  const DmNavigationIntent({
    required this.chatId,
    required this.friendId,
  });

  final String chatId;
  final String friendId;
}
