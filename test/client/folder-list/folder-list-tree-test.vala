/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class FolderList.TreeTest : TestCase {

    public TreeTest() {
        base("FolderList.TreeTest");
        add_test("scope_defaults_to_list_all", scope_defaults_to_list_all);
        add_test("list_all_hides_unified_virtual_folders", list_all_hides_unified_virtual_folders);
        add_test("select_real_inbox", select_real_inbox);
        add_test("select_unified_inbox", select_unified_inbox);
        add_test("select_unified_special_folder", select_unified_special_folder);
        add_test("account_scope_hides_other_accounts", account_scope_hides_other_accounts);
        add_test(
            "remove_account_clears_unified_inbox_selection",
            remove_account_clears_unified_inbox_selection
        );
        add_test(
            "remove_account_clears_unified_selection",
            remove_account_clears_unified_selection
        );
    }

    public void scope_defaults_to_list_all() throws GLib.Error {
        Tree tree = new Tree();
        Application.FolderContext sent = new_context_for_use("sent", SENT, 4);

        tree.add_folder(sent);

        assert(tree.current_scope.is_list_all);
        assert(!tree.select_unified_special_folder(SENT));
    }

    public void list_all_hides_unified_virtual_folders() throws GLib.Error {
        Tree tree = new Tree();
        Application.FolderContext first = new_context("first", 3);
        Application.FolderContext second = new_context("second", 4);

        tree.add_folder(first);
        tree.add_folder(second);

        assert(tree.current_scope.is_list_all);
        assert(!tree.unified_branch_is_visible());
        assert(!tree.select_unified_special_folder(INBOX));
        assert(!tree.select_combined_inbox());
    }

    public void select_real_inbox() throws GLib.Error {
        Tree tree = new Tree();
        Application.FolderContext first = new_context("first", 3);
        Application.FolderContext second = new_context("second", 4);
        int selected = 0;

        tree.add_folder(first);
        tree.add_folder(second);
        tree.folder_selected.connect((folder) => {
            if (folder == first.folder) {
                selected++;
            }
        });

        assert(tree.select_inbox(first.folder.account));
        assert(tree.selected == first.folder);
        assert(!tree.selected_is_unified_special_folder(INBOX));
        assert_equal<int?>(selected, 1);
    }

    public void select_unified_inbox() throws GLib.Error {
        Tree tree = new Tree();
        Application.FolderContext first = new_context("first", 3);
        Application.FolderContext second = new_context("second", 4);
        int selected = 0;

        tree.add_folder(first);
        tree.add_folder(second);
        tree.set_scope(new Scope.unified());
        tree.unified_special_folder_selected.connect((special_use) => {
            if (special_use == INBOX) {
                selected++;
            }
        });

        assert(tree.current_scope.is_unified);
        assert(tree.unified_branch_is_visible());
        assert(tree.select_unified_special_folder(INBOX));
        assert(tree.selected == null);
        assert(tree.selected_is_unified_special_folder(INBOX));
        assert(tree.selected_is_combined_inbox);
        assert_equal<int?>(selected, 1);

        tree.set_scope(new Scope.list_all());
        tree.select_folder(first.folder);
        assert(tree.selected == first.folder);
        assert(!tree.selected_is_unified_special_folder(INBOX));
    }

    public void select_unified_special_folder() throws GLib.Error {
        Tree tree = new Tree();
        Application.FolderContext sent = new_context_for_use("sent", SENT, 4);
        int selected = 0;

        tree.add_folder(sent);
        tree.set_scope(new Scope.unified());
        tree.unified_special_folder_selected.connect((special_use) => {
            if (special_use == SENT) {
                selected++;
            }
        });

        assert(tree.current_scope.is_unified);
        assert(tree.has_unified_special_folder(SENT));
        assert(tree.unified_branch_is_visible());
        assert(tree.select_unified_special_folder(SENT));
        assert(tree.selected == null);
        assert(tree.selected_is_unified_special_folder(SENT));
        assert(!tree.selected_is_combined_inbox);
        assert_equal<int?>(selected, 1);

        tree.set_scope(new Scope.list_all());
        tree.select_folder(sent.folder);
        assert(tree.selected == sent.folder);
        assert(!tree.selected_is_unified_special_folder(SENT));
    }

    public void account_scope_hides_other_accounts() throws GLib.Error {
        Tree tree = new Tree();
        Application.FolderContext first = new_context("first", 3);
        Application.FolderContext second = new_context("second", 4);
        int selected = 0;

        tree.add_folder(first);
        tree.add_folder(second);
        tree.folder_selected.connect((folder) => selected++);
        tree.set_scope(new Scope.for_account(first.folder.account));

        tree.select_folder(second.folder);
        assert(tree.selected == null);
        assert_equal<int?>(selected, 0);

        tree.select_folder(first.folder);
        assert(tree.selected == first.folder);
        assert_equal<int?>(selected, 1);
    }

    public void remove_account_clears_unified_inbox_selection() throws GLib.Error {
        Tree tree = new Tree();
        Application.FolderContext first = new_context("first", 3);
        Application.FolderContext second = new_context("second", 4);
        int selected = 0;

        tree.add_folder(first);
        tree.add_folder(second);
        tree.set_scope(new Scope.unified());
        tree.folder_selected.connect((folder) => selected++);

        assert(tree.select_unified_special_folder(INBOX));
        assert(tree.selected_is_unified_special_folder(INBOX));

        tree.remove_account(first.folder.account);
        assert(tree.selected == null);
        assert(!tree.selected_is_unified_special_folder(INBOX));
        assert_equal<int?>(selected, 1);
    }

    public void remove_account_clears_unified_selection() throws GLib.Error {
        Tree tree = new Tree();
        Application.FolderContext sent = new_context_for_use("sent", SENT, 4);
        int selected = 0;

        tree.add_folder(sent);
        tree.set_scope(new Scope.unified());
        tree.folder_selected.connect((folder) => selected++);

        assert(tree.select_unified_special_folder(SENT));
        assert(tree.selected_is_unified_special_folder(SENT));

        tree.remove_account(sent.folder.account);
        assert(tree.selected == null);
        assert(!tree.selected_is_unified_special_folder(SENT));
        assert_equal<int?>(selected, 1);
    }

    private Application.FolderContext new_context(string id, int unread) {
        return new_context_for_use(id, INBOX, unread);
    }

    private Application.FolderContext new_context_for_use(
        string id,
        Geary.Folder.SpecialUse used_as,
        int unread
    ) {
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
            new TestFolderProperties(unread),
            root.get_child(used_as.to_string()),
            used_as,
            null
        );
        return new Application.FolderContext(folder);
    }

    private class TestFolderProperties : Geary.FolderProperties {

        internal TestFolderProperties(int unread) {
            base(
                unread,
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
