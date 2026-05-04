import 'package:flutter_application_1/models/personnel_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonnelProfile', () {
    test('round trips nested data through map', () {
      final profile = PersonnelProfile(
        uid: 'u1',
        email: 'test@example.com',
        firstName: 'Іван',
        lastName: 'Петренко',
        patronymic: 'Іванович',
        militaryUnit: 'А0000',
        position: 'Інструктор',
        rankHistory: [
          RankHistoryEntry(
            rank: 'старший солдат',
            orderNumber: '12-РС',
            orderDate: DateTime(2025, 3, 13),
            isCurrent: true,
          ),
        ],
        education: [
          const EducationEntry(
            type: 'вища',
            institution: 'Університет',
            specialty: 'Психологія',
            degree: 'магістр',
            year: '2024',
          ),
        ],
        languageSkills: const [
          LanguageSkillEntry(
            language: 'Англійська',
            civilianLevel: 'B2',
            militaryLevel: 'СМР-2',
          ),
        ],
      );

      final restored = PersonnelProfile.fromMap(profile.toMap());

      expect(restored.uid, 'u1');
      expect(restored.fullName, 'Петренко Іван Іванович');
      expect(restored.rankHistory.single.orderDate, DateTime(2025, 3, 13));
      expect(restored.education.single.summary, contains('Психологія'));
      expect(restored.languageSkills.single.summary, contains('СМР-2'));
    });

    test('uses marked current rank for export row', () {
      final profile = PersonnelProfile(
        uid: 'u1',
        email: 'test@example.com',
        rank: 'солдат',
        staffRank: 'головний сержант',
        rankHistory: [
          RankHistoryEntry(
            rank: 'молодший сержант',
            orderNumber: '81-РС',
            orderDate: DateTime(2025, 3, 13),
            isCurrent: true,
          ),
          RankHistoryEntry(
            rank: 'солдат',
            orderNumber: '10',
            orderDate: DateTime(2024, 1, 1),
          ),
        ],
      );

      final fields = profile.toExportFields();

      expect(fields['staffAndRank'], 'головний сержант / молодший сержант');
      expect(fields['rankOrder'], '№81-РС від 13.03.2025');
    });

    test('custom export columns select values by stable keys', () {
      final profile = PersonnelProfile(
        uid: 'u1',
        email: 'test@example.com',
        militaryUnit: 'А2900',
        position: 'Сержант-інструктор',
        relocationReady: false,
        serviceType: 'mobilization',
        mobilizationDate: DateTime(2024, 4, 19),
      );

      final fields = profile.toExportFields();
      final selected = [
        'militaryUnit',
        'position',
        'service',
        'relocationReady',
      ].map((key) => fields[key]).toList();

      expect(selected, [
        'А2900',
        'Сержант-інструктор',
        'призваний під час мобілізації 19.04.2024',
        'не готовий',
      ]);
    });
  });
}
