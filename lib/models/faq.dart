/// A help-centre entry, served from the `faqs` table so support copy can change without a release.
class Faq {
  final String id;
  final String question;
  final String answer;

  const Faq({required this.id, required this.question, required this.answer});

  factory Faq.fromJson(Map<String, dynamic> json) => Faq(
        id: json['id'] as String,
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );
}
