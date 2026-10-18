import copy
import json
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

from coordinator import Coordinator, Handler


class Assignments(unittest.TestCase):
    def setUp(self):
        self.now = 100.0
        self.c = Coordinator(lambda: self.now)
        self.roster = {"main": "MainBee", "alts": ["AltOne", "AltTwo"],
            "catchers": ["OutsideOne", "OutsideTwo", "OutsideThree"], "field": "Pepper Patch"}
        self.seq = {}
        self.names = ["MainBee", "AltOne", "AltTwo", "OutsideOne", "OutsideTwo", "OutsideThree"]
        for name in self.names:
            self.sync(name)

    def sync(self, name, targets=None, busy=False, pos=None, server="server-1", roster=None):
        self.seq[name] = self.seq.get(name, 0) + 1
        return self.c.sync({"username": name, "server": server, "session": name + "-session", "seq": self.seq[name],
            "pos": pos or [0, 0, 0], "speed": 100, "busy": busy,
            "roster": roster or self.roster, "targets": targets or []})

    def target(self, owner="MainBee", key="fall-1", pos=None, field="Pepper Patch", ttl=2):
        return {"owner": owner, "key": key, "pos": pos or [10, 0, 0], "ttl": ttl, "points": 1, "field": field}

    def assigned(self):
        return {t["key"]: t["assigned"] for t in self.c.rooms["server-1"]["targets"].values()}

    def test_main_priority_and_stable_landing(self):
        r = self.sync("AltOne", [self.target()])
        self.assertEqual(self.assigned()["fall-1"], "mainbee")
        self.assertEqual(r["jobs"], [])
        self.assertEqual(len(self.sync("MainBee")["jobs"]), 1)

    def test_catcher_is_not_released_just_before_impact(self):
        self.sync("MainBee", [self.target()], pos=[10, 0, 0])
        self.now = 101.9
        reply = self.sync("MainBee", pos=[10, 0, 0])
        self.assertEqual(self.assigned()["fall-1"], "mainbee")
        self.assertEqual(len(reply["jobs"]), 1)
        self.assertGreater(reply["jobs"][0]["lease"], .3)

    def test_no_reassignment_during_a_committed_landing_lease(self):
        self.sync("MainBee", [self.target()], pos=[10, 0, 0])
        self.now += .8
        self.sync("AltOne")
        self.assertIsNone(self.assigned()["fall-1"])
        self.now += .4
        self.sync("AltOne")
        self.assertIsNone(self.assigned()["fall-1"], "backup stole a committed landing before its lease ended")

    def test_explicit_busy_release_can_yield_a_committed_landing(self):
        self.sync("MainBee", [self.target()], pos=[10, 0, 0])
        self.seq["MainBee"] += 1
        self.c.sync({"protocol": 2, "active_key": "", "username": "MainBee", "server": "server-1",
            "session": "MainBee-session", "seq": self.seq["MainBee"], "pos": [10, 0, 0], "speed": 100,
            "busy": True, "roster": self.roster, "targets": []})
        self.sync("AltOne")
        self.assertEqual(self.assigned()["fall-1"], "altone")

    def test_alt_owner_first_then_main_then_owner(self):
        self.sync("AltOne", [self.target("AltOne")], pos=[10, 0, 0])
        self.assertEqual(self.assigned()["fall-1"], "altone")
        self.now = 102.0
        self.sync("AltOne", pos=[10, 0, 0])
        self.now += .3
        self.sync("MainBee", [self.target("AltOne", "fall-2")])
        self.assertEqual(self.assigned()["fall-2"], "mainbee")
        self.now = 104.3
        self.sync("MainBee", pos=[10, 0, 0])
        self.now += .3
        self.sync("AltOne", [self.target("AltOne", "fall-3")], pos=[10, 0, 0])
        self.assertEqual(self.assigned()["fall-3"], "altone")

    def test_busy_main_gets_backup_and_returns_next_landing(self):
        self.sync("MainBee", busy=True)
        self.sync("AltOne", [self.target()])
        self.assertIn(self.assigned()["fall-1"], ("altone", "alttwo"))
        self.sync("MainBee")
        self.assertNotEqual(self.assigned()["fall-1"], "mainbee", "do not steal active backup landing")
        self.now += 2.4
        for n in self.names:
            self.sync(n)
        self.sync("MainBee", [self.target(key="fall-2")])
        self.assertEqual(self.assigned()["fall-2"], "mainbee")

    def test_outside_nearest_catcher_when_core_unreachable(self):
        for n in self.names[:3]:
            self.sync(n, pos=[1000, 0, 0])
        self.sync("OutsideOne", pos=[100, 0, 0])
        self.sync("OutsideTwo", pos=[20, 0, 0])
        self.sync("OutsideThree", pos=[80, 0, 0])
        self.sync("OutsideTwo", [self.target(field="Mountain Top Field")], pos=[20, 0, 0])
        self.assertEqual(self.assigned()["fall-1"], "outsidetwo")

    def test_outside_spawning_alt_keeps_its_growth_turn(self):
        self.sync("AltOne", [self.target("AltOne", field="Mountain Top Field")])
        self.assertEqual(self.assigned()["fall-1"], "altone")

    def test_busy_handoff_waits_out_old_lease(self):
        self.sync("MainBee", [self.target()])
        self.sync("MainBee", busy=True)
        self.assertIsNone(self.assigned()["fall-1"])
        self.now += .4
        self.sync("AltOne")
        self.assertIsNone(self.assigned()["fall-1"])
        self.now += .4
        self.sync("AltOne")
        self.assertEqual(self.assigned()["fall-1"], "altone")

    def test_server_isolation(self):
        self.sync("MainBee", [self.target()], server="other-server")
        self.assertEqual(self.c.rooms["server-1"]["targets"], {})

    def test_no_duplicate_assignments_for_simultaneous_combos(self):
        targets = [self.target(key="first"), self.target("AltOne", "second"), self.target("AltTwo", "third")]
        self.sync("MainBee", targets)
        assigned = [v for v in self.assigned().values() if v]
        self.assertEqual(len(assigned), len(set(assigned)))

    def test_unknown_owner_not_guessed(self):
        self.sync("MainBee", [self.target("UnknownUser")])
        self.assertEqual(self.assigned(), {})

    def test_unreachable_and_wrong_height_not_assigned(self):
        self.sync("MainBee", [self.target(pos=[5000, 1000, 0])])
        self.assertIsNone(self.assigned()["fall-1"])

    def test_stale_members_not_assigned(self):
        self.now += 1
        self.sync("AltOne", [self.target()])
        self.assertEqual(self.assigned()["fall-1"], "altone")

    def test_duplicate_observations_and_deadline_not_extended(self):
        self.sync("MainBee", [self.target()])
        self.now += .1
        self.sync("AltOne", [self.target(key="different-client-key", ttl=1.95)])
        self.assertEqual(len(self.assigned()), 1)
        self.assertAlmostEqual(self.c.rooms["server-1"]["targets"]["fall-1"]["deadline"], 102)

    def test_roster_mismatch_and_validation(self):
        r = copy.deepcopy(self.roster)
        r["field"] = "Rose Field"
        self.assertFalse(self.sync("AltOne", roster=r)["ok"])
        r["alts"] = ["MainBee", "AltOne"]
        with self.assertRaises(ValueError):
            self.sync("MainBee", roster=r)
        with self.assertRaises(ValueError):
            self.sync("MainBee", pos=[float("nan"), 0, 0])

    def test_long_run_state_is_bounded(self):
        for i in range(2000):
            self.now += 3
            self.sync("MainBee", [self.target(key=f"fall-{i}")])
            room = self.c.rooms["server-1"]
            self.assertLessEqual(len(room["targets"]), 2)
            self.assertLessEqual(len(room["players"]), 6)
        self.now += 31
        self.c.prune(self.now)
        self.assertEqual(self.c.rooms, {})


class HttpTests(unittest.TestCase):
    def test_real_http_auth_and_private_setup(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        server.coordinator = Coordinator()
        server.key = "test-key"
        server.admin = "test-admin"
        server.public_url = "https://example.trycloudflare.com"
        server.message = "Ready"
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        url = f"http://127.0.0.1:{server.server_port}"
        try:
            with urllib.request.urlopen(url + "/status?admin=test-admin") as r:
                self.assertEqual(json.load(r)["message"], "Ready")
            req = urllib.request.Request(url + "/status?admin=test-admin", headers={"CF-Ray": "external"})
            with self.assertRaises(urllib.error.HTTPError) as e:
                urllib.request.urlopen(req)
            self.assertEqual(e.exception.code, 404)
            e.exception.close()
            req = urllib.request.Request(url + "/v1/sync", data=b"{}", headers={"Content-Type": "application/json"})
            with self.assertRaises(urllib.error.HTTPError) as e:
                urllib.request.urlopen(req)
            self.assertEqual(e.exception.code, 401)
            e.exception.close()
            req.add_header("Authorization", "Bearer test-key")
            with self.assertRaises(urllib.error.HTTPError) as e:
                urllib.request.urlopen(req)
            self.assertEqual(e.exception.code, 400)
            e.exception.close()
        finally:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    unittest.main()
