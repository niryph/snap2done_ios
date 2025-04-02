import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static Future<bool> hasAcceptedTerms() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await Supabase.instance.client
          .from('user_terms')
          .select('accepted')
          .eq('user_id', user.id)
          .single();
      
      // With newer Supabase versions, response is directly the data
      return response != null && response['accepted'] == true;
    } catch (e) {
      // Handle case where record doesn't exist or other errors
      return false;
    }
  }

  static Future<void> acceptTerms() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await Supabase.instance.client
          .from('user_terms')
          .upsert({'user_id': user.id, 'accepted': true});
    } catch (e) {
      throw Exception('Error accepting terms: $e');
    }
  }
}
