/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class ConversationList.RowTest : TestCase {

    private Application.Configuration? config = null;

    public RowTest() {
        base("ConversationList.RowTest");
        add_test("shows_account_context_when_requested", shows_account_context_when_requested);
        add_test("hides_account_context_by_default", hides_account_context_by_default);
        add_test("uses_source_folder_for_account_context", uses_source_folder_for_account_context);
    }

    public override void set_up() {
        this.config = new Application.Configuration(Application.Client.SCHEMA_ID);
    }

    public override void tear_down() {
        this.config = null;
    }

    public void shows_account_context_when_requested() throws GLib.Error {
        assert_account_context_visible(true);
    }

    public void hides_account_context_by_default() throws GLib.Error {
        assert_account_context_visible(false);
    }

    private void assert_account_context_visible(bool visible) throws GLib.Error {
        Mock.Folder folder;
        Mock.Account account;
        Geary.App.Conversation conversation;
        Geary.App.ConversationMonitor monitor = load_conversation(
            "Work", "Preview text", out conversation, out folder, out account
        );
        ConversationList.Row row = new ConversationList.Row(
            this.config,
            conversation,
            folder,
            folder.account.information.display_name,
            false,
            visible
        );

        assert(has_visible_label(row, "Work") == visible);
        assert(has_visible_label(row, "·") == visible);
        assert(has_visible_label(row, "Preview text"));

        row.destroy();
        stop_monitor(monitor, folder, account);
    }

    public void uses_source_folder_for_account_context() throws GLib.Error {
        Mock.Folder folder;
        Mock.Account account;
        Geary.App.Conversation conversation;
        Geary.App.ConversationMonitor monitor = load_conversation(
            "Work", "Preview text", out conversation, out folder, out account
        );
        Mock.Folder source = new_folder("Personal", INBOX);
        ConversationList.Row row = new ConversationList.Row(
            this.config,
            conversation,
            source,
            source.account.information.display_name,
            false,
            true
        );

        assert(has_visible_label(row, "Personal"));
        assert(!has_visible_label(row, "Work"));

        row.destroy();
        stop_monitor(monitor, folder, account);
    }

    private Geary.App.ConversationMonitor load_conversation(
        string account_label,
        string preview,
        out Geary.App.Conversation conversation,
        out Mock.Folder folder,
        out Mock.Account account
    ) throws GLib.Error {
        account = new_account(account_label);
        folder = new_folder(account_label, INBOX, account);

        Geary.Email email = new Geary.Email(new Mock.EmailIdentifer(1));
        GLib.DateTime now = new GLib.DateTime.now_local();
        email.set_email_properties(new Mock.EmailProperties(now));
        email.set_send_date(new Geary.RFC822.Date(now));
        email.set_message_subject(new Geary.RFC822.Subject("Subject"));
        email.set_message_preview(new Geary.RFC822.PreviewText.from_string(preview));
        email.set_originators(
            new Geary.RFC822.MailboxAddresses.single(
                new Geary.RFC822.MailboxAddress("Sender", "sender@example.com")
            ),
            null,
            null
        );
        email.set_full_references(
            new Geary.RFC822.MessageID("message@example.com"),
            null,
            null
        );
        Gee.List<Geary.Email> emails = new Gee.ArrayList<Geary.Email>();
        emails.add(email);
        Gee.MultiMap<Geary.EmailIdentifier, Geary.FolderPath> paths =
            new Gee.HashMultiMap<Geary.EmailIdentifier, Geary.FolderPath>();
        paths.set(email.id, folder.path);

        folder.expect_call("open_async");
        folder.expect_call("list_email_by_id_async").returns_object(emails);
        account.expect_call("get_special_folder");
        account.expect_call("get_special_folder");
        account.expect_call("get_special_folder");
        account.expect_call("local_search_message_id_async");
        account.expect_call("get_containing_folders_async").returns_object(paths);

        Geary.App.ConversationMonitor monitor = new Geary.App.ConversationMonitor(
            folder, Geary.Email.Field.NONE, 1
        );
        monitor.start_monitoring.begin(NONE, null, this.async_completion);
        monitor.start_monitoring.end(async_result());
        wait_for_signal(monitor, "conversations-added");

        conversation = Geary.Collection.first(monitor.read_only_view);
        return monitor;
    }

    private Mock.Account new_account(string label) {
        Geary.AccountInformation info = new Geary.AccountInformation(
            label.down(),
            OTHER,
            new Mock.CredentialsMediator(),
            new Geary.RFC822.MailboxAddress(null, "%s@example.com".printf(label.down()))
        );
        info.label = label;
        return new Mock.Account(info);
    }

    private Mock.Folder new_folder(
        string account_label,
        Geary.Folder.SpecialUse used_as,
        Mock.Account? account = null
    ) {
        Mock.Account folder_account = account ?? new_account(account_label);
        Geary.FolderRoot root = new Geary.FolderRoot("#" + account_label, false);
        return new Mock.Folder(
            folder_account,
            new Mock.FolderPoperties(),
            root.get_child(used_as.to_string()),
            used_as,
            null
        );
    }

    private void stop_monitor(Geary.App.ConversationMonitor monitor,
                              Mock.Folder folder,
                              Mock.Account account) throws GLib.Error {
        folder.expect_call("close_async");
        monitor.stop_monitoring.begin(null, this.async_completion);
        monitor.stop_monitoring.end(async_result());
        folder.assert_expectations();
        account.assert_expectations();
    }

    private bool has_visible_label(Gtk.Widget widget, string text) {
        Gtk.Label? label = widget as Gtk.Label;
        if (label != null && label.visible && label.get_text() == text) {
            return true;
        }

        Gtk.Container? container = widget as Gtk.Container;
        if (container != null) {
            foreach (Gtk.Widget child in container.get_children()) {
                if (has_visible_label(child, text)) {
                    return true;
                }
            }
        }
        return false;
    }

}
