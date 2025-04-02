import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDebug {
  static final client = Supabase.instance.client;
  
  // Test database permissions and RLS policies
  static Future<void> testPermissions() async {
    final results = <String, String>{};
    
    try {
      debugPrint('---------- SUPABASE DEBUG TEST STARTED ----------');
      
      // Check if user is authenticated
      final user = client.auth.currentUser;
      if (user == null) {
        debugPrint('ERROR: Not authenticated. Please sign in first.');
        return;
      }
      
      debugPrint('Authenticated as: ${user.email} (${user.id})');
      
      // Test profiles table
      try {
        debugPrint('Testing profiles table...');
        final profile = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        
        results['profiles-select'] = profile != null 
            ? 'SUCCESS: Profile found' 
            : 'WARNING: No profile found for current user';
            
        debugPrint(results['profiles-select']);
      } catch (e) {
        results['profiles-select'] = 'ERROR: $e';
        debugPrint('ERROR testing profiles table select: $e');
      }
      
      // Test user_preferences table
      try {
        debugPrint('Testing user_preferences table...');
        final prefs = await client
            .from('user_preferences')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        
        results['preferences-select'] = prefs != null 
            ? 'SUCCESS: Preferences found' 
            : 'WARNING: No preferences found for current user';
            
        debugPrint(results['preferences-select']);
      } catch (e) {
        results['preferences-select'] = 'ERROR: $e';
        debugPrint('ERROR testing user_preferences table select: $e');
      }
      
      // Test cards table
      try {
        debugPrint('Testing cards table...');
        final cards = await client
            .from('cards')
            .select('id, title')
            .eq('user_id', user.id)
            .limit(5);
        
        results['cards-select'] = 'SUCCESS: Found ${cards.length} cards';
        debugPrint(results['cards-select']);
      } catch (e) {
        results['cards-select'] = 'ERROR: $e';
        debugPrint('ERROR testing cards table select: $e');
      }
      
      // Test raw RPC function (if available)
      /* 
      // Disabled to prevent error messages in the console
      // This test requires the 'test_permissions' function to be deployed to the database
      // See getTestRpcFunctionSQL() below for the function definition
      try {
        debugPrint('Testing RPC function (this may fail if the function does not exist in the database)...');
        // Note: This is a debug function that may not exist in all environments.
        // The function is defined in fix_rls.sql but may not be deployed.
        // This error can be safely ignored in normal operation.
        final rpcResult = await client.rpc('test_permissions');
        results['rpc-test'] = 'SUCCESS: RPC function returned: $rpcResult';
        debugPrint(results['rpc-test']);
      } catch (e) {
        results['rpc-test'] = 'ERROR: $e';
        debugPrint('Note: Error testing RPC function is expected if the function is not deployed: $e');
      }
      */
      
      debugPrint('---------- SUPABASE DEBUG SUMMARY ----------');
      results.forEach((key, value) => debugPrint('$key: $value'));
      debugPrint('---------- SUPABASE DEBUG TEST ENDED ----------');
    } catch (e) {
      debugPrint('ERROR during debug test: $e');
    }
  }
  
  // Create a test RPC function on the Supabase database
  static String getTestRpcFunctionSQL() {
    return '''
    -- Function to test permissions
    CREATE OR REPLACE FUNCTION test_permissions()
    RETURNS JSON AS \$\$
    DECLARE
      result JSON;
    BEGIN
      result = json_build_object(
        'user_id', auth.uid(),
        'has_profile', EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()),
        'has_preferences', EXISTS (SELECT 1 FROM user_preferences WHERE user_id = auth.uid()),
        'card_count', (SELECT COUNT(*) FROM cards WHERE user_id = auth.uid())
      );
      
      RETURN result;
    END;
    \$\$ LANGUAGE plpgsql SECURITY DEFINER;

    -- Grant execution permissions
    GRANT EXECUTE ON FUNCTION test_permissions TO authenticated;
    GRANT EXECUTE ON FUNCTION test_permissions TO anon;
    ''';
  }
} 