/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class FolderList.UnifiedFolderEntryTest : TestCase {

    public UnifiedFolderEntryTest() {
        base("FolderList.UnifiedFolderEntryTest");
        add_test("sums_unread_counts_for_inbox", sums_unread_counts_for_inbox);
        add_test("sums_total_counts_for_drafts", sums_total_counts_for_drafts);
        add_test("updates_when_count_changes", updates_when_count_changes);
        add_test("updates_when_folder_removed", updates_when_folder_removed);
    }

    public void sums_unread_counts_for_inbox() throws GLib.Error {
        UnifiedFolderEntry entry = new UnifiedFolderEntry(INBOX);

        entry.add_folder(new_context("first", INBOX, 10, 3));
        entry.add_folder(new_context("second", INBOX, 20, 4));

        assert_equal<int?>(entry.get_count(), 7);
    }

    public void sums_total_counts_for_drafts() throws GLib.Error {
        UnifiedFolderEntry entry = new UnifiedFolderEntry(DRAFTS);

        entry.add_folder(new_context("first", DRAFTS, 10, 3));
        entry.add_folder(new_context("second", DRAFTS, 20, 4));

        assert_equal<int?>(entry.get_count(), 30);
    }

    public void updates_when_count_changes() throws GLib.Error {
        UnifiedFolderEntry entry = new UnifiedFolderEntry(DRAFTS);
        Application.FolderContext context = new_context("first", DRAFTS, 10, 3);
        TestFolderProperties properties = context.folder.properties as TestFolderProperties;
        int changed = 0;

        entry.add_folder(context);
        entry.entry_changed.connect(() => changed++);

        properties.set_total(12);

        assert_equal<int?>(entry.get_count(), 12);
        assert_equal<int?>(changed, 1);
    }

    public void updates_when_folder_removed() throws GLib.Error {
        UnifiedFolderEntry entry = new UnifiedFolderEntry(INBOX);
        Application.FolderContext first = new_context("first", INBOX, 10, 3);
        Application.FolderContext second = new_context("second", INBOX, 20, 4);

        entry.add_folder(first);
        entry.add_folder(second);
        entry.remove_folder(first.folder.account);

        assert_equal<int?>(entry.get_count(), 4);
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

        internal void set_total(int total) {
            this.email_total = total;
        }

    }

}
