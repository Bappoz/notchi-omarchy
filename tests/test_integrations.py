import importlib.util
import json
from pathlib import Path
import sys
import unittest
from unittest import mock

PLUGIN=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PLUGIN))
import integrations as api

class NetworkBoundaryTests(unittest.TestCase):
    def test_insecure_public_http_never_sends_a_request(self):
        with mock.patch.object(api,'build_opener') as opener:
            with self.assertRaises(ValueError):api.request('http://public.example/api/states')
        opener.assert_not_called()

    def test_missing_hostname_is_a_validation_error(self):
        with self.assertRaises(ValueError):api.request('http:///api/states')

    def test_userinfo_in_url_never_sends_credentials(self):
        with mock.patch.object(api,'build_opener') as opener:
            with self.assertRaises(ValueError):api.request('https://user:password@example.test/')
        opener.assert_not_called()

    def test_redirects_are_not_followed(self):
        self.assertIsNone(api.NoRedirect().redirect_request(None,None,None,None,None,None))

    def test_missing_home_credentials_never_contact_network(self):
        with mock.patch.object(api,'config',return_value={}),mock.patch.object(api,'request') as request:
            with self.assertRaises(ValueError):api.home_states()
        request.assert_not_called()

    def test_home_command_rejects_entity_that_was_not_in_devices(self):
        with mock.patch.object(api,'home_config',return_value=({},'https://home.example',{'Authorization':'Bearer TEST'})),mock.patch.object(api,'home_states',return_value={'homeDevices':[]}),mock.patch.object(api,'request') as request:
            with self.assertRaises(ValueError):api.home_command('light.unlisted','turn_on','')
        request.assert_not_called()

    def test_home_command_rejects_unsupported_service(self):
        with mock.patch.object(api,'home_config',return_value=({},'https://home.example',{})),mock.patch.object(api,'home_states',return_value={'homeDevices':[{'id':'light.study','domain':'light','modes':[],'fans':[]}]}),mock.patch.object(api,'request') as request:
            with self.assertRaises(ValueError):api.home_command('light.study','delete_everything','')
        request.assert_not_called()

    def test_home_devices_do_not_expose_arbitrary_attributes_or_token(self):
        rows=[{'entity_id':'light.study','state':'on','attributes':{'friendly_name':'Study','password':'HIDDEN','secret':'HIDDEN'}}]
        with mock.patch.object(api,'home_config',return_value=({},'https://home.example',{'Authorization':'Bearer HIDDEN'})),mock.patch.object(api,'request',return_value=rows):
            result=api.home_states()
        encoded=json.dumps(result)
        self.assertNotIn('HIDDEN',encoded)
        self.assertEqual(result['homeDevices'][0]['name'],'Study')

    def test_spotify_missing_token_does_not_contact_network(self):
        with mock.patch.object(api,'config',return_value={}),mock.patch.object(api,'request') as request:
            with self.assertRaises(ValueError):api.spotify_devices()
        request.assert_not_called()


class LyricsLookupTests(unittest.TestCase):
    def test_exact_track_loads_synced_lyrics(self):
        payload={"syncedLyrics":"[00:01.00]Test fixture line", "plainLyrics":"Test fixture line"}
        with mock.patch.object(api,"request",return_value=payload) as request:
            result=api.lyrics("Fixture Artist","Fixture Track","Fixture Album","180")
        self.assertTrue(result["synced"])
        self.assertEqual(result["lyrics"][0]["time"],1)
        request.assert_called_once()

    def test_missing_exact_record_searches_matching_track(self):
        candidate={"artistName":"Fixture Artist","trackName":"Fixture Track", "duration":181,
                   "syncedLyrics":"[00:02.00]Matched test line"}
        with mock.patch.object(api,"request",side_effect=[ValueError("HTTP 404"),[candidate]]):
            result=api.lyrics("Fixture Artist","Fixture Track","Different Album","180")
        self.assertTrue(result["synced"])
        self.assertEqual(result["lyrics"][0]["time"],2)

    def test_plain_lyrics_remain_readable_without_fake_timestamps(self):
        payload={"plainLyrics":"First fixture line\nSecond fixture line", "syncedLyrics":None}
        with mock.patch.object(api,"request",side_effect=[payload,[]]):
            result=api.lyrics("Fixture Artist","Fixture Track","","180")
        self.assertFalse(result["synced"])
        self.assertEqual([line["time"] for line in result["lyrics"]],[None,None])

    def test_search_never_uses_an_unrelated_artist_or_version(self):
        wrong={"artistName":"Unrelated Artist","trackName":"Fixture Track", "duration":181,
               "syncedLyrics":"[00:02.00]Wrong record"}
        live={"artistName":"Fixture Artist","trackName":"Fixture Track - Live", "duration":400,
              "syncedLyrics":"[00:02.00]Wrong version"}
        with mock.patch.object(api,"request",side_effect=[ValueError("HTTP 404"),[wrong,live]]):
            with self.assertRaises(ValueError):api.lyrics("Fixture Artist","Fixture Track","","180")

    def test_empty_player_metadata_never_contacts_network(self):
        with mock.patch.object(api,"request") as request:
            with self.assertRaises(ValueError):api.lyrics("","","","0")
        request.assert_not_called()


class IntegrationSettingsTests(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.directory=tempfile.TemporaryDirectory();self.addCleanup(self.directory.cleanup)
        self.patch=mock.patch.object(api.local,'CONFIG',Path(self.directory.name));self.patch.start();self.addCleanup(self.patch.stop)

    def values(self):
        return {'latitude':'-23.55','longitude':'-46.63','timezone':'America/Sao_Paulo','prayerMethod':'MWL',
                'base':'BRL','currencies':'USD, EUR','coins':'bitcoin','stocks':'','homeUrl':'https://ha.example',
                'homeToken':'TEST_PRIVATE_TOKEN','spotifyToken':'TEST_SPOTIFY_TOKEN','stockKey':'TEST_KEY'}

    def test_saved_tokens_are_not_returned_to_the_ui(self):
        result=api.save_settings(self.values())
        encoded=json.dumps(result)
        self.assertNotIn('TEST_PRIVATE_TOKEN',encoded)
        self.assertNotIn('TEST_SPOTIFY_TOKEN',encoded)
        self.assertNotIn('TEST_KEY',encoded)
        self.assertTrue(result['integrationSettings']['hasHomeToken'])
        path=api.local.CONFIG/'integrations.json'
        self.assertEqual(path.stat().st_mode&0o777,0o600)

    def test_empty_token_fields_preserve_the_existing_connection(self):
        api.save_settings(self.values())
        values=self.values();values['homeToken']='';values['spotifyToken']='';values['stockKey']=''
        api.save_settings(values)
        saved=api.config()
        self.assertEqual(saved['homeAssistant']['token'],'TEST_PRIVATE_TOKEN')
        self.assertEqual(saved['spotify']['token'],'TEST_SPOTIFY_TOKEN')

    def test_invalid_coordinates_do_not_create_a_configuration_file(self):
        values=self.values();values['latitude']='nan'
        with self.assertRaises(ValueError):api.save_settings(values)
        self.assertFalse((api.local.CONFIG/'integrations.json').exists())

    def test_private_looking_public_hostname_cannot_use_plain_http(self):
        with mock.patch.object(api,'build_opener') as opener:
            with self.assertRaises(ValueError):api.request('http://10.example.test/api/states')
        opener.assert_not_called()

if __name__=='__main__':unittest.main()
