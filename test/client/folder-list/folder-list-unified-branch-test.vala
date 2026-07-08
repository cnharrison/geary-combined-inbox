/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class FolderList.UnifiedBranchTest : TestCase {

    public UnifiedBranchTest() {
        base("FolderList.UnifiedBranchTest");
        add_test("adds_supported_special_folders_in_order", adds_supported_special_folders_in_order);
        add_test("aggregates_counts", aggregates_counts);
        add_test("removes_entry_when_last_folder_removed", removes_entry_when_last_folder_removed);
        add_test("ignores_unsupported_folders", ignores_unsupported_folders);
    }

    public void adds_supported_special_folders_in_order() throws GLib.Error {
        UnifiedBranch branch = new UnifiedBranch();

        branch.add_folder(new_context("trash", TRASH, 10, 3));
        branch.add_folder(new_context("inbox", INBOX, 10, 4));
        branch.add_folder(new_context("sent", SENT, 10, 0));
        branch.add_folder(new_context("drafts", DRAFTS, 7, 7));

        Gee.List<Sidebar.Entry>? children = branch.get_children(branch.get_root());
        assert(children != null);
        assert_equal<int?>(children.size, 4);
        assert_special_use(children.get(0), INBOX);
        assert_special_use(children.get(1), DRAFTS);
        assert_special_use(children.get(2), SENT);
        assert_special_use(children.get(3), TRASH);
    }

    public void aggregates_counts() throws GLib.Error {
        UnifiedBranch branch = new UnifiedBranch();

        branch.add_folder(new_context("first", DRAFTS, 3, 1));
        branch.add_folder(new_context("second", DRAFTS, 4, 2));

        UnifiedFolderEntry? entry = branch.get_entry_for_special_use(DRAFTS);
        assert(entry != null);
        assert_equal<int?>(entry.get_count(), 7);
    }

    public void removes_entry_when_last_folder_removed() throws GLib.Error {
        UnifiedBranch branch = new UnifiedBranch();
        Application.FolderContext first = new_context("first", INBOX, 10, 3);
        Application.FolderContext second = new_context("second", INBOX, 20, 4);

        branch.add_folder(first);
        branch.add_folder(second);
        branch.remove_folder(first);

        UnifiedFolderEntry? entry = branch.get_entry_for_special_use(INBOX);
        assert(entry != null);
        assert_equal<int?>(entry.get_count(), 4);

        branch.remove_folder(second);
        assert(branch.get_entry_for_special_use(INBOX) == null);
        assert_equal<int?>(branch.get_child_count(branch.get_root()), 0);
    }

    public void ignores_unsupported_folders() throws GLib.Error {
        UnifiedBranch branch = new UnifiedBranch();

        branch.add_folder(new_context("custom", NONE, 10, 3));
        branch.add_folder(new_context("search", SEARCH, 10, 3));

        assert(branch.get_children(branch.get_root()) == null);
    }

    private void assert_special_use(Sidebar.Entry entry,
                                    Geary.Folder.SpecialUse expected)
        throws GLib.Error {
        UnifiedFolderEntry folder_entry = (UnifiedFolderEntry) entry;
        assert(folder_entry.special_use == expected);
    }

    private Application.FolderContext new_context(string id,
                                                  Geary.Folder.SpecialUse use,
                                                  int total,
                                                  int unread) {
        Geary.AccountInformation info = new Geary.AccountInformation(
            id,
            OTHER,
            new Mock.CredentialsMediator(),
            new Geary.RFC822.MailboxAddress(id, "%s@example.com".printf(id))
        );
        Mock.Account account = new Mock.Account(info);
        Geary.FolderRoot root = new Geary.FolderRoot("#" + id, false);
        Mock.Folder folder = new Mock.Folder(
            account,
            new TestFolderProperties(total, unread),
            root.get_child(use.to_string()),
            use,
            null
        );
        return new Application.FolderContext(folder);
    }

    private class TestFolderProperties : Geary.FolderProperties {

        internal TestFolderProperties(int total, int unread) {
            base(
                total,
                unread,
                Geary.Trillian.FALSE,
                Geary.Trillian.FALSE,
                Geary.Trillian.TRUE,
                false,
                false,
                false
            );
        }

    }

}
