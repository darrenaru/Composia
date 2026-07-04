abstract class ChatEvent {
  const ChatEvent();
}

class ChatMessageSent extends ChatEvent {
  final String text;
  const ChatMessageSent(this.text);
}

class ChatRetryRequested extends ChatEvent {
  const ChatRetryRequested();
}
