import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_app/main.dart';
import 'package:ledger_app/models/friend.dart';
import 'package:ledger_app/models/transaction.dart';
import 'package:ledger_app/services/storage_service.dart';

void main() {
  group('Friend and Transaction Unit Tests', () {
    test('Transaction serialization and deserialization', () {
      final tx = Transaction(
        amount: 150.50,
        date: DateTime.parse('2026-09-21T12:00:00.000Z'),
        reason: 'Lunch bill',
      );

      final json = tx.toJson();
      expect(json['amount'], 150.50);
      expect(json['reason'], 'Lunch bill');

      final deserialized = Transaction.fromJson(json);
      expect(deserialized.amount, 150.50);
      expect(deserialized.reason, 'Lunch bill');
    });

    test('Friend serialization and deserialization', () {
      final friend = Friend(
        id: '101',
        name: 'Alice',
        initialTransaction: 50.0,
        initialReason: 'Coffee',
      );

      final json = friend.toJson();
      expect(json['name'], 'Alice');
      expect(json['amountOwed'], 50.0);
      expect((json['transactions'] as List).length, 1);

      final deserialized = Friend.fromJson(json);
      expect(deserialized.id, '101');
      expect(deserialized.name, 'Alice');
      expect(deserialized.amountOwed, 50.0);
      expect(deserialized.transactions.length, 1);
      expect(deserialized.transactions.first.reason, 'Coffee');
    });

    test('FriendStorage parseBackupJson valid input', () {
      final sampleBackup = jsonEncode([
        {
          'id': '1',
          'name': 'Bob',
          'amountOwed': 200.0,
          'transactions': [
            {'amount': 200.0, 'date': '2026-09-21T10:00:00.000', 'reason': 'Loan'}
          ]
        }
      ]);

      final friends = FriendStorage.parseBackupJson(sampleBackup);
      expect(friends.length, 1);
      expect(friends.first.name, 'Bob');
      expect(friends.first.amountOwed, 200.0);
    });

    test('FriendStorage parseBackupJson invalid input throws FormatException', () {
      expect(() => FriendStorage.parseBackupJson(''), throwsFormatException);
      expect(() => FriendStorage.parseBackupJson('{ "invalid": true }'), throwsFormatException);
      expect(() => FriendStorage.parseBackupJson('[{"no_name": 123}]'), throwsFormatException);
    });
  });

  group('Widget Smoke Tests', () {
    testWidgets('App renders Ledger title screen', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MyApp), findsOneWidget);
    });
  });
}
