/* Copyright 2016 Software Freedom Conservancy Inc.
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class FolderList.Tree : Sidebar.Tree, Geary.BaseInterface {


    public const Gtk.TargetEntry[] TARGET_ENTRY_LIST = {
        { "application/x-geary-mail", Gtk.TargetFlags.SAME_APP, 0 }
    };

    private const int UNIFIED_ORDINAL = -2;
    private const int SEARCH_ORDINAL = -1;


    public signal void folder_selected(Geary.Folder? folder);
    public signal void folder_activated(Geary.Folder? folder);
    public signal void unified_special_folder_selected(Geary.Folder.SpecialUse special_use);
    public signal void unified_special_folder_activated(Geary.Folder.SpecialUse special_use);
    public signal void combined_inbox_selected();
    public signal void combined_inbox_activated();
    public signal void copy_conversation(Geary.Folder folder);
    public signal void move_conversation(Geary.Folder folder);

    public Geary.Folder? selected { get; private set; default = null; }
    internal Scope current_scope { get; private set; default = new Scope.list_all(); }
    public Geary.Folder.SpecialUse selected_unified_special_use {
        get; private set; default = NONE;
    }
    public bool selected_is_combined_inbox {
        get { return selected_is_unified_special_folder(INBOX); }
    }

    private Gee.HashMap<Geary.Account, AccountBranch> account_branches
        = new Gee.HashMap<Geary.Account, AccountBranch>();
    private UnifiedBranch unified_branch = new UnifiedBranch();
    private SearchBranch? search_branch = null;


    public Tree() {
        base(TARGET_ENTRY_LIST, Gdk.DragAction.COPY | Gdk.DragAction.MOVE, drop_handler);
        base_ref();
        set_activate_on_single_click(true);
        entry_selected.connect(on_entry_selected);
        entry_activated.connect(on_entry_activated);

        // GtkTreeView binds Ctrl+N to "move cursor to next".  Not so interested in that, so we'll
        // remove it.
        unowned Gtk.BindingSet? binding_set = Gtk.BindingSet.find("GtkTreeView");
        assert(binding_set != null);
        Gtk.BindingEntry.remove(binding_set, Gdk.Key.N, Gdk.ModifierType.CONTROL_MASK);

        this.visible = true;
    }

    ~Tree() {
        base_unref();
    }

    public override void get_preferred_width(out int minimum_size, out int natural_size) {
        minimum_size = 360;
        natural_size = 500;
    }

    public void set_has_new(Geary.Folder folder, bool has_new) {
        FolderEntry? entry = get_folder_entry(folder);
        if (entry != null) {
            entry.set_has_new(has_new);
        }

    }

    private void drop_handler(Gdk.DragContext context, Sidebar.Entry? entry,
        Gtk.SelectionData data, uint info, uint time) {
    }

    private FolderEntry? get_folder_entry(Geary.Folder folder) {
        AccountBranch? account_branch = account_branches.get(folder.account);
        return (account_branch == null ? null :
            account_branch.get_entry_for_path(folder.path));
    }

    public override bool accept_cursor_changed() {
        bool can_switch = true;
        var parent = get_toplevel() as Application.MainWindow;
        if (parent != null) {
            can_switch = parent.close_composer(false);
        }
        return can_switch;
    }

    private void on_entry_selected(Sidebar.SelectableEntry selectable) {
        UnifiedFolderEntry? unified = selectable as UnifiedFolderEntry;
        if (unified != null) {
            select_unified_entry(unified);
            return;
        }

        AbstractFolderEntry? entry = selectable as AbstractFolderEntry;
        if (entry != null) {
            this.selected = entry.folder;
            this.selected_unified_special_use = NONE;
            folder_selected(entry.folder);
        }
    }

    private void on_entry_activated(Sidebar.SelectableEntry selectable) {
        UnifiedFolderEntry? unified = selectable as UnifiedFolderEntry;
        if (unified != null) {
            unified_special_folder_activated(unified.special_use);
            if (unified.special_use == INBOX) {
                combined_inbox_activated();
            }
            return;
        }

        AbstractFolderEntry? entry = selectable as AbstractFolderEntry;
        if (entry != null) {
            folder_activated(entry.folder);
        }
    }

    private void select_unified_entry(UnifiedFolderEntry entry) {
        this.selected = null;
        this.selected_unified_special_use = entry.special_use;
        unified_special_folder_selected(entry.special_use);
        if (entry.special_use == INBOX) {
            combined_inbox_selected();
        }
    }

    public void set_user_folders_root_name(Geary.Account account, string name) {
        if (account_branches.has_key(account))
            account_branches.get(account).user_folder_group.rename(name);
    }

    public void add_folder(Application.FolderContext context) {
        Geary.Folder folder = context.folder;
        Geary.Account account = folder.account;

        if (!account_branches.has_key(account)) {
            this.account_branches.set(account, new AccountBranch(account));
            account.information.notify["ordinal"].connect(on_ordinal_changed);
        }

        var account_branch = this.account_branches.get(account);
        account_branch.add_folder(context);

        this.unified_branch.add_folder(context);
        update_scope_branches();
    }

    public void remove_folder(Application.FolderContext context) {
        Geary.Folder folder = context.folder;
        Geary.Account account = folder.account;

        var account_branch = this.account_branches.get(account);

        // If this is the current folder, unselect it.
        var entry = account_branch.get_entry_for_path(folder.path);

        // if found and selected, report nothing is selected in preparation for its removal
        if (entry != null && is_selected(entry)) {
            deselect_folder();
        }

        this.unified_branch.remove_folder(context);
        if (this.selected_unified_special_use != NONE &&
            this.selected_unified_special_use == folder.used_as &&
            this.unified_branch.get_entry_for_special_use(folder.used_as) == null) {
            deselect_folder();
        }

        account_branch.remove_folder(folder.path);
        update_scope_branches();
    }

    public void remove_account(Geary.Account account) {
        account.information.notify["ordinal"].disconnect(on_ordinal_changed);

        // If the active selection depends on this account, unselect it.
        if (this.selected_unified_special_use != NONE ||
            (this.selected != null && this.selected.account == account)) {
            deselect_folder();
        }

        AccountBranch? account_branch = account_branches.get(account);
        if (account_branch != null) {
            if (has_branch(account_branch))
                prune(account_branch);
            account_branches.unset(account);
        }

        this.unified_branch.remove_account(account);

        update_scope_branches();
    }

    private void update_scope_branches() {
        foreach (AccountBranch branch in this.account_branches.values) {
            update_account_branch(branch);
        }

        update_unified_branch();
    }

    private void update_account_branch(AccountBranch branch) {
        bool should_show = (
            this.current_scope.is_list_all ||
            (this.current_scope.is_account && this.current_scope.account == branch.account)
        );
        set_branch_visible(branch, should_show, branch.account.information.ordinal);
    }

    private void update_unified_branch() {
        set_branch_visible(
            this.unified_branch,
            this.current_scope.is_unified &&
                this.unified_branch.get_child_count(this.unified_branch.get_root()) > 0,
            UNIFIED_ORDINAL
        );
    }

    private void set_branch_visible(Sidebar.Branch branch,
                                    bool should_show,
                                    int position) {
        if (should_show) {
            if (!branch.get_show_branch()) {
                branch.set_show_branch(true);
            }
            if (!has_branch(branch)) {
                graft(branch, position);
            }
        } else if (has_branch(branch)) {
            prune(branch);
        }
    }

    private bool folder_is_visible(Geary.Folder folder) {
        return folder_is_visible_in_scope(folder, this.current_scope);
    }

    private bool folder_is_visible_in_scope(Geary.Folder folder, Scope scope) {
        return scope.is_list_all ||
            (scope.is_account && scope.account == folder.account);
    }

    private bool selection_is_visible_in_scope(Scope scope) {
        if (this.selected_unified_special_use != NONE) {
            return scope.is_unified;
        }

        return this.selected == null || folder_is_visible_in_scope(this.selected, scope);
    }

    internal void set_scope(Scope scope) {
        if (!this.current_scope.equal_to(scope)) {
            if (!selection_is_visible_in_scope(scope)) {
                deselect_folder();
            }

            this.current_scope = scope;
            update_scope_branches();
        }
    }

    public void select_folder(Geary.Folder to_select) {
        if (!folder_is_visible(to_select)) {
            return;
        }

        if (this.selected != to_select || this.selected_unified_special_use != NONE) {
            FolderEntry? entry = get_folder_entry(to_select);
            if (entry != null) {
                place_cursor(entry, false);
            }
        }
    }

    public bool select_inbox(Geary.Account account) {
        AccountBranch? branch = this.account_branches.get(account);
        if (branch == null) {
            return false;
        }

        foreach (FolderEntry entry in branch.folder_entries.values) {
            if (entry.folder.used_as == INBOX && folder_is_visible(entry.folder)) {
                place_cursor(entry, false);
                return true;
            }
        }
        return false;
    }

    /** Compatibility alias for the former combined-inbox entry. */
    public bool select_combined_inbox() {
        return select_unified_special_folder(INBOX);
    }

    public bool select_unified_special_folder(Geary.Folder.SpecialUse special_use) {
        if (!has_branch(unified_branch)) {
            return false;
        }

        UnifiedFolderEntry? entry = unified_branch.get_entry_for_special_use(special_use);
        if (entry == null) {
            return false;
        }

        return place_cursor(entry, false);
    }

    public bool selected_is_unified_special_folder(Geary.Folder.SpecialUse special_use) {
        return this.selected_unified_special_use == special_use;
    }

    internal bool unified_branch_is_visible() {
        return has_branch(this.unified_branch);
    }

    internal bool has_unified_special_folder(Geary.Folder.SpecialUse special_use) {
        return this.unified_branch.get_entry_for_special_use(special_use) != null;
    }

    public void deselect_folder() {
        Gtk.TreeModel model = get_model();
        Gtk.TreeIter iter;
        if (model.get_iter_first(out iter)) {
            Gtk.TreePath? first = model.get_path(iter);
            if (first != null) {
                set_cursor(first, null, false);
            }
        }

        get_selection().unselect_all();
        this.selected = null;
        this.selected_unified_special_use = NONE;
        folder_selected(null);
    }

    public override bool drag_motion(Gdk.DragContext context, int x, int y, uint time) {
        // Run the base version first.
        bool ret = base.drag_motion(context, x, y, time);

        // Update the cursor for copy or move.
        Gdk.ModifierType mask;
        double[] axes = new double[2];
        context.get_device().get_state(context.get_dest_window(), axes, out mask);
        if ((mask & Gdk.ModifierType.CONTROL_MASK) != 0) {
            Gdk.drag_status(context, Gdk.DragAction.COPY, time);
        } else {
            Gdk.drag_status(context, Gdk.DragAction.MOVE, time);
        }
        return ret;
    }

    public void set_search(Geary.Engine engine,
                           Geary.App.SearchFolder search_folder) {
        if (search_branch != null && has_branch(search_branch)) {
            // We already have a search folder.  If it's the same one, just
            // select it.  If it's a new search folder, remove the old one and
            // continue.
            if (search_folder == search_branch.get_search_folder()) {
                place_cursor(search_branch.get_root(), false);
                return;
            } else {
                remove_search();
            }
        }

        search_branch = new SearchBranch(search_folder, engine);
        graft(search_branch, SEARCH_ORDINAL);
        place_cursor(search_branch.get_root(), false);
    }

    public void remove_search() {
        if (search_branch != null) {
            prune(search_branch);
            search_branch = null;
        }
    }
    private void on_ordinal_changed() {
        if (account_branches.size <= 1)
            return;

        // Remove branches where the ordinal doesn't match the graft position.
        Gee.ArrayList<AccountBranch> branches_to_reorder = new Gee.ArrayList<AccountBranch>();
        foreach (AccountBranch branch in account_branches.values) {
            if (get_position_for_branch(branch) != branch.account.information.ordinal) {
                prune(branch);
                branches_to_reorder.add(branch);
            }
        }

        // Re-add branches with new positions.
        foreach (AccountBranch branch in branches_to_reorder)
            graft(branch, branch.account.information.ordinal);
    }

}
