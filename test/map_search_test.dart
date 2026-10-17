import 'package:flutter_test/flutter_test.dart';
import 'package:mymp/data/election.dart';
import 'package:mymp/models.dart';
import 'package:mymp/search.dart';

/// The election map's search: a seat by its member, its own name or its
/// district, in either script and either digits, spelt the way readers type.
void main() {
  ElectionSeat seat(
    int no,
    String slug,
    String name,
    String alt,
    String district,
    String districtAlt,
    String member,
    String memberEn,
  ) => ElectionSeat(
    no: no,
    slug: slug,
    name: name,
    seatAlt: alt,
    districtSlug: district.toLowerCase(),
    districtName: district,
    districtAlt: districtAlt,
    member: MemberBrief(
      id: '$no',
      slug: slug,
      nameBn: member,
      nameEn: memberEn,
    ),
  );

  // As the Bangla answer gives them: Bangla names, the English beside them.
  final seats = [
    seat(
      1,
      'panchagarh-1',
      'পঞ্চগড়-১',
      'Panchagarh-1',
      'পঞ্চগড়',
      'Panchagarh',
      'ব্যারিস্টার মুহাম্মদ নওশাদ জমির',
      'Barrister Muhammad Nawshad Zamir',
    ),
    seat(
      190,
      'dhaka-17',
      'ঢাকা-১৭',
      'Dhaka-17',
      'ঢাকা',
      'Dhaka',
      'তারেক রহমান',
      'Tarique Rahman',
    ),
    seat(
      191,
      'dhaka-18',
      'ঢাকা-১৮',
      'Dhaka-18',
      'ঢাকা',
      'Dhaka',
      'এস এম জাহাঙ্গীর হোসেন',
      'S M Jahangir Hossain',
    ),
    seat(
      173,
      'dhaka-1',
      'ঢাকা-১',
      'Dhaka-1',
      'ঢাকা',
      'Dhaka',
      'খোন্দকার আবু আশফাক',
      'Khondokar Abu Ashfaque',
    ),
  ];
  final finder = TextSearch<ElectionSeat>(
    seats,
    (s) => [
      ('${s.member?.nameBn ?? ''} ${s.member?.nameEn ?? ''}', 1.5),
      ('${s.name} ${s.seatAlt ?? ''} ${s.slug.replaceAll('-', ' ')}', 1.4),
      ('${s.districtName} ${s.districtAlt ?? ''}', 1.0),
    ],
  );
  List<String> find(String q) => [for (final s in finder.search(q)) s.slug];

  test('a seat however its number and dash are typed', () {
    for (final q in [
      'ঢাকা-১৭',
      'ঢাকা ১৭',
      'ঢাকা 17',
      'dhaka 17',
      'Dhaka-17',
      'dhaka17',
    ]) {
      expect(find(q).first, 'dhaka-17', reason: q);
    }
    // "ঢাকা ১" is Dhaka-1, not every seat whose number starts with 1.
    expect(find('ঢাকা ১'), ['dhaka-1']);
  });

  test('a member in either script, by part of the name or a misspelling', () {
    for (final q in [
      'তারেক',
      'tarique',
      'tarek rahman',
      'Tareq',
      'তারেক রহমান',
    ]) {
      expect(find(q).first, 'dhaka-17', reason: q);
    }
    expect(find('নওশাদ জমির'), ['panchagarh-1']);
    expect(find('md nawshad'), ['panchagarh-1']);
  });

  test(
    'a district finds its seats; nonsense finds nothing; one letter waits',
    () {
      expect(find('ঢাকা').toSet(), {'dhaka-17', 'dhaka-18', 'dhaka-1'});
      expect(find('dhaka').toSet(), {'dhaka-17', 'dhaka-18', 'dhaka-1'});
      expect(find('জিজিজিজি'), isEmpty);
      expect(find('ঢ'), isEmpty);
    },
  );
}
