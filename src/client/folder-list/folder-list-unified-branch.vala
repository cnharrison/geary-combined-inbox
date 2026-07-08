/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** A branch containing virtual unified special-folder entries. */
public class FolderList.UnifiedBranch : Sidebar.Branch {

    private const Geary.Folder.SpecialUse[] SPECIAL_USE_ORDERING = {
        INBOX,
        FLAGGED,
        IMPORTANT,
        DRAFTS,
        OUTBOX,
        SENT,
        ARCHIVE,
        ALL_MAIL,
        TRASH,
        JUNK
    };


    private Gee.Map<Geary.Folder.SpecialUse?, UnifiedFolderEntry> entries =
        new Gee.HashMap<Geary.Folder.SpecialUse?, UnifiedFolderEntry>(
            special_use_hash,
            special_use_equal
        );
    private Gee.Map<Geary.Folder.SpecialUse?, Gee.Set<Geary.Account>> accounts =
        new Gee.HashMap<Geary.Folder.SpecialUse?, Gee.Set<Geary.Account>>(
            special_use_hash,
            special_use_equal
        );


    public UnifiedBranch() {
        base(
            new Sidebar.Header(_("All Accounts")),
            HIDE_IF_EMPTY | STARTUP_OPEN_GROUPING,
            unified_comparator
        );
    }

    public UnifiedFolderEntry? get_entry_for_special_use(
        Geary.Folder.SpecialUse special_use
    ) {
        return this.entries.get(special_use);
    }

    public void add_folder(Application.FolderContext context) {
        Geary.Folder.SpecialUse special_use = context.folder.used_as;
        if (!Application.Location.supports_unified_special_folder(special_use)) {
            return;
        }

        UnifiedFolderEntry? entry = this.entries.get(special_use);
        if (entry == null) {
            entry = new UnifiedFolderEntry(special_use);
            this.entries.set(special_use, entry);
            this.accounts.set(special_use, new Gee.HashSet<Geary.Account>());
            graft(get_root(), entry);
        }

        entry.add_folder(context);
        this.accounts.get(special_use).add(context.folder.account);
    }

    public void remove_folder(Application.FolderContext context) {
        remove_folder_for_account(context.folder.used_as, context.folder.account);
    }

    public void remove_account(Geary.Account account) {
        var special_uses = new Gee.ArrayList<Geary.Folder.SpecialUse?>();
        special_uses.add_all(this.entries.keys);

        foreach (Geary.Folder.SpecialUse? special_use in special_uses) {
            Gee.Set<Geary.Account>? accounts = this.accounts.get(special_use);
            if (accounts != null && accounts.contains(account)) {
                remove_folder_for_account((Geary.Folder.SpecialUse) special_use, account);
            }
        }
    }

    private void remove_folder_for_account(Geary.Folder.SpecialUse special_use,
                                           Geary.Account account) {
        if (!Application.Location.supports_unified_special_folder(special_use)) {
            return;
        }

        UnifiedFolderEntry? entry = this.entries.get(special_use);
        Gee.Set<Geary.Account>? accounts = this.accounts.get(special_use);
        if (entry == null || accounts == null || !accounts.contains(account)) {
            debug(
                "Could not remove %s from unified branch for %s",
                special_use.to_string(),
                account.to_string()
            );
            return;
        }

        entry.remove_folder(account);
        accounts.remove(account);
        if (accounts.is_empty) {
            prune(entry);
            this.entries.unset(special_use);
            this.accounts.unset(special_use);
        }
    }

    private static uint special_use_hash(Geary.Folder.SpecialUse? special_use) {
        return GLib.int_hash(special_use);
    }

    private static bool special_use_equal(Geary.Folder.SpecialUse? a,
                                          Geary.Folder.SpecialUse? b) {
        return (Geary.Folder.SpecialUse) a == (Geary.Folder.SpecialUse) b;
    }

    private static int unified_comparator(Sidebar.Entry a, Sidebar.Entry b) {
        UnifiedFolderEntry entry_a = (UnifiedFolderEntry) a;
        UnifiedFolderEntry entry_b = (UnifiedFolderEntry) b;
        return get_position(entry_a.special_use) - get_position(entry_b.special_use);
    }

    private static int get_position(Geary.Folder.SpecialUse special_use) {
        for (int i = 0; i < SPECIAL_USE_ORDERING.length; i++) {
            if (SPECIAL_USE_ORDERING[i] == special_use) {
                return i;
            }
        }
        assert_not_reached();
    }

}
