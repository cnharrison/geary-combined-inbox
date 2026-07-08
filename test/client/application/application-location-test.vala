/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class Application.LocationTest : TestCase {

    public LocationTest() {
        base("Application.LocationTest");
        add_test("none", none);
        add_test("folder", folder);
        add_test("unified_special_folder", unified_special_folder);
        add_test("supports_unified_special_folders", supports_unified_special_folders);
    }

    public void none() throws GLib.Error {
        Location location = new Location.none();

        assert(location.kind == Location.Kind.NONE);
        assert(location.folder == null);
        assert(!location.is_virtual);
        assert(!location.is_unified_special_folder(INBOX));
    }

    public void folder() throws GLib.Error {
        Geary.Folder folder = new_folder("Inbox", INBOX);
        Location location = new Location.for_folder(folder);

        assert(location.kind == Location.Kind.FOLDER);
        assert(location.folder == folder);
        assert(location.is_folder(folder));
        assert(!location.is_virtual);
        assert(!location.is_unified_special_folder(INBOX));
    }

    public void unified_special_folder() throws GLib.Error {
        Location location = new Location.unified_special_folder(INBOX);

        assert(location.kind == Location.Kind.UNIFIED_SPECIAL_FOLDER);
        assert(location.folder == null);
        assert(location.is_virtual);
        assert(location.is_unified_special_folder(INBOX));
        assert(!location.is_unified_special_folder(SENT));
    }

    public void supports_unified_special_folders() throws GLib.Error {
        assert(Location.supports_unified_special_folder(INBOX));
        assert(Location.supports_unified_special_folder(SENT));
        assert(Location.supports_unified_special_folder(DRAFTS));
        assert(!Location.supports_unified_special_folder(NONE));
        assert(!Location.supports_unified_special_folder(SEARCH));
        assert(!Location.supports_unified_special_folder(CUSTOM));
    }

    private Geary.Folder new_folder(string name,
                                    Geary.Folder.SpecialUse special_use) {
        Geary.FolderRoot root = new Geary.FolderRoot("#test", false);
        return new Mock.Folder(
            null,
            null,
            root.get_child(name),
            special_use,
            null
        );
    }

}
