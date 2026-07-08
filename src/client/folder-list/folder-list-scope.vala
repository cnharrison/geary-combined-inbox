/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Describes which account/folder set is shown in the folder list. */
internal class FolderList.Scope : Geary.BaseObject {

    public enum Kind {
        LIST_ALL,
        ACCOUNT,
        UNIFIED
    }

    public Kind kind { get; private set; default = Kind.LIST_ALL; }

    public Geary.Account? account { get; private set; default = null; }

    public bool is_list_all {
        get { return this.kind == Kind.LIST_ALL; }
    }

    public bool is_account {
        get { return this.kind == Kind.ACCOUNT; }
    }

    public bool is_unified {
        get { return this.kind == Kind.UNIFIED; }
    }

    public Scope.list_all() {
        this.kind = Kind.LIST_ALL;
    }

    public Scope.for_account(Geary.Account account) {
        this.kind = Kind.ACCOUNT;
        this.account = account;
    }

    public Scope.unified() {
        this.kind = Kind.UNIFIED;
    }

    public bool equal_to(Scope other) {
        return this.kind == other.kind &&
            (this.kind != Kind.ACCOUNT || this.account == other.account);
    }

    public string get_display_name() {
        switch (this.kind) {
        case LIST_ALL:
            return _("All Accounts");

        case ACCOUNT:
            return this.account.information.display_name;

        case UNIFIED:
            return _("Unified Folders");

        default:
            assert_not_reached();
        }
    }

    public string to_string() {
        switch (this.kind) {
        case LIST_ALL:
            return "Scope: list all";

        case ACCOUNT:
            return "Scope: " + this.account.to_string();

        case UNIFIED:
            return "Scope: unified";

        default:
            assert_not_reached();
        }
    }

}
