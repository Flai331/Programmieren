class LetterModel {
  final String id;
  final String? companyId;
  final String? customerId;

  // Briefkopf
  final String letterForm;     // 'A' (Behörden) | 'B' (Standard, default)
  final String envelopeFormat; // 'DL' | 'C6' | 'C5' | 'C4' | 'B6' | 'B5'
  final DateTime? letterDate;
  final String? location;

  // Bezugszeichen (DIN 5008)
  final String? refYour;
  final String? refYourDate;
  final String? refOur;
  final String? refOurDate;

  // Inhalt
  final String? subject;
  final String? salutation;
  final String? body;
  final String? closing;
  final String? signerName;

  // Empfänger-Snapshot
  final String? recipientZusatz;
  final String? recipientName;
  final String? recipientStreet;
  final String? recipientCity;
  final String? recipientCountry;

  // Anzeige
  final bool showFoldMarks;
  final bool showPunchMark;

  // Meta
  final String status; // 'draft' | 'sent'
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LetterModel({
    required this.id,
    this.companyId,
    this.customerId,
    this.letterForm = 'B',
    this.envelopeFormat = 'DL',
    this.letterDate,
    this.location,
    this.refYour,
    this.refYourDate,
    this.refOur,
    this.refOurDate,
    this.subject,
    this.salutation,
    this.body,
    this.closing,
    this.signerName,
    this.recipientZusatz,
    this.recipientName,
    this.recipientStreet,
    this.recipientCity,
    this.recipientCountry,
    this.showFoldMarks = true,
    this.showPunchMark = true,
    this.status = 'draft',
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'company_id': companyId,
        'customer_id': customerId,
        'letter_form': letterForm,
        'envelope_format': envelopeFormat,
        'letter_date': letterDate?.toIso8601String().substring(0, 10),
        'location': location,
        'ref_your': refYour,
        'ref_your_date': refYourDate,
        'ref_our': refOur,
        'ref_our_date': refOurDate,
        'subject': subject,
        'salutation': salutation,
        'body': body,
        'closing': closing,
        'signer_name': signerName,
        'recipient_zusatz': recipientZusatz,
        'recipient_name': recipientName,
        'recipient_street': recipientStreet,
        'recipient_city': recipientCity,
        'recipient_country': recipientCountry,
        'show_fold_marks': showFoldMarks,
        'show_punch_mark': showPunchMark,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory LetterModel.fromMap(Map<String, dynamic> m) => LetterModel(
        id: m['id'] as String,
        companyId: m['company_id'] as String?,
        customerId: m['customer_id'] as String?,
        letterForm: (m['letter_form'] as String?) ?? 'B',
        envelopeFormat: (m['envelope_format'] as String?) ?? 'DL',
        letterDate: m['letter_date'] != null
            ? DateTime.parse(m['letter_date'] as String)
            : null,
        location: m['location'] as String?,
        refYour: m['ref_your'] as String?,
        refYourDate: m['ref_your_date'] as String?,
        refOur: m['ref_our'] as String?,
        refOurDate: m['ref_our_date'] as String?,
        subject: m['subject'] as String?,
        salutation: m['salutation'] as String?,
        body: m['body'] as String?,
        closing: m['closing'] as String?,
        signerName: m['signer_name'] as String?,
        recipientZusatz: m['recipient_zusatz'] as String?,
        recipientName: m['recipient_name'] as String?,
        recipientStreet: m['recipient_street'] as String?,
        recipientCity: m['recipient_city'] as String?,
        recipientCountry: m['recipient_country'] as String?,
        showFoldMarks: (m['show_fold_marks'] as bool?) ?? true,
        showPunchMark: (m['show_punch_mark'] as bool?) ?? true,
        status: (m['status'] as String?) ?? 'draft',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
      );

  LetterModel copyWith({
    String? id,
    String? companyId,
    String? customerId,
    String? letterForm,
    String? envelopeFormat,
    DateTime? letterDate,
    String? location,
    String? refYour,
    String? refYourDate,
    String? refOur,
    String? refOurDate,
    String? subject,
    String? salutation,
    String? body,
    String? closing,
    String? signerName,
    String? recipientZusatz,
    String? recipientName,
    String? recipientStreet,
    String? recipientCity,
    String? recipientCountry,
    bool? showFoldMarks,
    bool? showPunchMark,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      LetterModel(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        customerId: customerId ?? this.customerId,
        letterForm: letterForm ?? this.letterForm,
        envelopeFormat: envelopeFormat ?? this.envelopeFormat,
        letterDate: letterDate ?? this.letterDate,
        location: location ?? this.location,
        refYour: refYour ?? this.refYour,
        refYourDate: refYourDate ?? this.refYourDate,
        refOur: refOur ?? this.refOur,
        refOurDate: refOurDate ?? this.refOurDate,
        subject: subject ?? this.subject,
        salutation: salutation ?? this.salutation,
        body: body ?? this.body,
        closing: closing ?? this.closing,
        signerName: signerName ?? this.signerName,
        recipientZusatz: recipientZusatz ?? this.recipientZusatz,
        recipientName: recipientName ?? this.recipientName,
        recipientStreet: recipientStreet ?? this.recipientStreet,
        recipientCity: recipientCity ?? this.recipientCity,
        recipientCountry: recipientCountry ?? this.recipientCountry,
        showFoldMarks: showFoldMarks ?? this.showFoldMarks,
        showPunchMark: showPunchMark ?? this.showPunchMark,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
