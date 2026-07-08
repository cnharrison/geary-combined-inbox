/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** A selectable virtual entry aggregating one special-use folder per account. */
public class FolderList.UnifiedFolderEntry : Geary.BaseObject,
    Sidebar.Entry, Sidebar.SelectableEntry {


    public Geary.Folder.SpecialUse special_use { get; private set; }

    private Gee.Map<Geary.Account, Application.FolderContext> folders =
        new Gee.HashMap<Geary.Account, Application.FolderContext>();
    private string display_name;


    public UnifiedFolderEntry(Geary.Folder.SpecialUse special_use) {
        assert(Application.Location.supports_unified_special_folder(special_use));
        this.special_use = special_use;
        this.display_name = get_special_use_display_name(special_use);
    }

    public void add_folder(Application.FolderContext context) {
        assert(context.folder.used_as == this.special_use);

        Geary.Account account = context.folder.account;
        if (this.folders.has_key(account)) {
            remove_folder(account);
        }

        this.folders.set(account, context);
        connect_folder(context);
        entry_changed();
    }

    public void remove_folder(Geary.Account account) {
        Application.FolderContext? context = this.folders.get(account);
        if (context == null) {
            debug(
                "Could not remove %s folder from unified folder entry for %s",
                this.special_use.to_string(),
                account.to_string()
            );
            return;
        }

        disconnect_folder(context);
        this.folders.unset(account);
        entry_changed();
    }

    ~UnifiedFolderEntry() {
        foreach (Application.FolderContext context in this.folders.values) {
            disconnect_folder(context);
        }
    }

    public virtual string get_sidebar_name() {
        return this.display_name;
    }

    public virtual string? get_sidebar_tooltip() {
        return null;
    }

    public virtual string? get_sidebar_icon() {
        switch (this.special_use) {
        case INBOX:
            return "mail-inbox-symbolic";

        case DRAFTS:
            return "mail-drafts-symbolic";

        case SENT:
            return "mail-sent-symbolic";

        case FLAGGED:
            return "starred-symbolic";

        case IMPORTANT:
            return "task-due-symbolic";

        case ALL_MAIL:
        case ARCHIVE:
            return "mail-archive-symbolic";

        case JUNK:
            return "dialog-warning-symbolic";

        case TRASH:
            return "user-trash-symbolic";

        case OUTBOX:
            return "mail-outbox-symbolic";

        default:
            assert_not_reached();
        }
    }

    public int get_count() {
        int count = 0;
        foreach (Application.FolderContext context in this.folders.values) {
            switch (context.displayed_count) {
            case TOTAL:
                count += context.folder.properties.email_total;
                break;

            case UNREAD:
                count += context.folder.properties.email_unread;
                break;

            case NONE:
                break;
            }
        }
        return count;
    }

    public virtual string to_string() {
        return "UnifiedFolderEntry: " + get_sidebar_name();
    }

    private static string get_special_use_display_name(
        Geary.Folder.SpecialUse special_use
    ) {
        string? display_name = Util.I18n.to_folder_type_display_name(special_use);
        assert(display_name != null);
        return display_name;
    }

    private void connect_folder(Application.FolderContext context) {
        context.folder.properties.notify[Geary.FolderProperties.PROP_NAME_EMAIL_TOTAL]
            .connect(on_count_changed);
        context.folder.properties.notify[Geary.FolderProperties.PROP_NAME_EMAIL_UNREAD]
            .connect(on_count_changed);
    }

    private void disconnect_folder(Application.FolderContext context) {
        context.folder.properties.notify[Geary.FolderProperties.PROP_NAME_EMAIL_TOTAL]
            .disconnect(on_count_changed);
        context.folder.properties.notify[Geary.FolderProperties.PROP_NAME_EMAIL_UNREAD]
            .disconnect(on_count_changed);
    }

    private void on_count_changed() {
        entry_changed();
    }

}
