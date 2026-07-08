/*
 * Copyright © 2017 Software Freedom Conservancy Inc.
 * Copyright © 2021 Michael Gratton <mike@vee.net>
 * Copyright © 2022 Cédric Bellegarde <cedric.bellegarde@adishatz.org>
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */


/**
 * The Application HeaderBar
 *
 * @see Application.MainWindow
 */
[GtkTemplate (ui = "/org/gnome/Geary/components-headerbar-application.ui")]
public class Components.ApplicationHeaderBar : Hdy.HeaderBar {

    private enum ScopeKind {
        LIST_ALL,
        UNIFIED,
        ACCOUNT
    }

    private class ScopeRow : Gtk.ListBoxRow {

        public ScopeKind kind { get; private set; }
        public Geary.Account? source_account { get; private set; default = null; }

        private Gtk.Label label = new Gtk.Label(null);
        private Gtk.Image selected_icon = new Gtk.Image.from_icon_name(
            "object-select-symbolic", Gtk.IconSize.MENU
        );


        public ScopeRow.list_all() {
            this.kind = ScopeKind.LIST_ALL;
            build();
            update_label();
        }

        public ScopeRow.unified() {
            this.kind = ScopeKind.UNIFIED;
            build();
            update_label();
        }

        public ScopeRow.account(Geary.Account account) {
            this.kind = ScopeKind.ACCOUNT;
            this.source_account = account;
            build();
            update_label();
        }

        public void update_label() {
            this.label.label = get_display_name();
        }

        public string get_display_name() {
            switch (this.kind) {
            case LIST_ALL:
                return _("All Accounts");

            case UNIFIED:
                return _("Unified Folders");

            case ACCOUNT:
                return this.source_account.information.display_name;

            default:
                assert_not_reached();
            }
        }

        public void set_selected(bool selected) {
            this.selected_icon.visible = selected;
        }

        private void build() {
            this.label.halign = Gtk.Align.START;
            this.label.hexpand = true;
            this.selected_icon.no_show_all = true;

            Gtk.Box layout = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            layout.margin = 6;
            layout.add(this.label);
            layout.add(this.selected_icon);
            layout.show_all();

            add(layout);
            set_selected(false);
            show();
        }

    }


    [GtkChild] private unowned Gtk.MenuButton app_menu_button;
    [GtkChild] public unowned MonitoredSpinner spinner;

    private Gtk.MenuButton scope_menu_button = new Gtk.MenuButton();
    private Gtk.Label scope_label = new Gtk.Label(null);
    private Gtk.ListBox scope_list = new Gtk.ListBox();
    private Gtk.Popover scope_popover;
    private ScopeRow list_all_scope_row = new ScopeRow.list_all();
    private ScopeRow unified_scope_row = new ScopeRow.unified();
    private Gee.Map<Geary.Account,ScopeRow> account_scope_rows =
        new Gee.HashMap<Geary.Account,ScopeRow>();


    public signal void scope_list_all_selected();
    public signal void scope_unified_selected();
    public signal void scope_account_selected(Geary.Account account);


    construct {
        Gtk.Builder builder = new Gtk.Builder.from_resource(
            "/org/gnome/Geary/components-menu-application.ui"
        );
        MenuModel app_menu = (MenuModel) builder.get_object("app_menu");

        this.app_menu_button.popover = new Gtk.Popover.from_model(null, app_menu);

        this.scope_list.selection_mode = Gtk.SelectionMode.BROWSE;
        this.scope_list.set_sort_func(sort_scope_rows);
        this.scope_list.set_header_func(scope_row_header);
        this.scope_list.row_activated.connect(on_scope_row_activated);
        this.scope_list.add(this.list_all_scope_row);
        this.scope_list.add(this.unified_scope_row);
        this.scope_list.show();

        this.scope_popover = new Gtk.Popover(this.scope_menu_button);
        this.scope_popover.add(this.scope_list);

        Gtk.Box scope_button_layout = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 3);
        scope_button_layout.add(this.scope_label);
        scope_button_layout.add(new Gtk.Image.from_icon_name(
            "pan-down-symbolic", Gtk.IconSize.MENU
        ));
        scope_button_layout.show_all();

        this.scope_menu_button.add(scope_button_layout);
        this.scope_menu_button.popover = this.scope_popover;
        this.scope_menu_button.focus_on_click = false;
        this.scope_menu_button.no_show_all = true;
        this.scope_menu_button.tooltip_text = _("Choose folder scope");
        this.scope_menu_button.get_accessible().set_name(_("Folder Scope"));
        this.unified_scope_row.no_show_all = true;
        this.custom_title = this.scope_menu_button;

        set_scope_list_all();
        set_scope_controls_available(false);
    }

    public void show_app_menu() {
        this.app_menu_button.clicked();
    }

    public void add_scope_account(Geary.Account account) {
        if (this.account_scope_rows.has_key(account)) {
            return;
        }

        ScopeRow row = new ScopeRow.account(account);
        this.account_scope_rows.set(account, row);
        account.information.notify["label"].connect(on_account_changed);
        account.information.notify["ordinal"].connect(on_account_changed);
        this.scope_list.add(row);
        this.scope_list.invalidate_sort();
        this.scope_list.invalidate_headers();
    }

    public void remove_scope_account(Geary.Account account) {
        ScopeRow? row = this.account_scope_rows.get(account);
        if (row == null) {
            return;
        }

        account.information.notify["label"].disconnect(on_account_changed);
        account.information.notify["ordinal"].disconnect(on_account_changed);
        this.scope_list.remove(row);
        this.account_scope_rows.unset(account);
        this.scope_list.invalidate_headers();
    }

    public void set_scope_controls_available(bool available) {
        if (!available && this.scope_list.get_selected_row() == this.unified_scope_row) {
            set_scope_list_all();
        }

        this.unified_scope_row.set_visible(available);
        this.scope_menu_button.set_visible(available);
        this.scope_list.invalidate_headers();
    }

    public void set_scope_list_all() {
        set_scope_row(this.list_all_scope_row);
    }

    public void set_scope_unified() {
        set_scope_row(this.unified_scope_row);
    }

    public void set_scope_account(Geary.Account account) {
        ScopeRow? row = this.account_scope_rows.get(account);
        if (row != null) {
            set_scope_row(row);
        }
    }

    private void set_scope_row(ScopeRow row) {
        this.list_all_scope_row.set_selected(row == this.list_all_scope_row);
        this.unified_scope_row.set_selected(row == this.unified_scope_row);
        foreach (ScopeRow account_row in this.account_scope_rows.values) {
            account_row.set_selected(row == account_row);
        }

        this.scope_label.label = row.get_display_name();
        this.scope_list.select_row(row);
    }

    private void on_account_changed() {
        foreach (ScopeRow row in this.account_scope_rows.values) {
            row.update_label();
        }
        this.scope_list.invalidate_sort();
        Gtk.ListBoxRow? selected = this.scope_list.get_selected_row();
        ScopeRow? scope_row = selected as ScopeRow;
        if (scope_row != null) {
            this.scope_label.label = scope_row.get_display_name();
        }
    }

    private void on_scope_row_activated(Gtk.ListBoxRow row) {
        ScopeRow? scope_row = row as ScopeRow;
        if (scope_row == null) {
            return;
        }

        set_scope_row(scope_row);
        this.scope_popover.hide();

        switch (scope_row.kind) {
        case LIST_ALL:
            scope_list_all_selected();
            break;

        case UNIFIED:
            scope_unified_selected();
            break;

        case ACCOUNT:
            scope_account_selected(scope_row.source_account);
            break;

        default:
            assert_not_reached();
        }
    }

    private void scope_row_header(Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        ScopeRow? scope_row = row as ScopeRow;
        ScopeRow? previous_scope = before as ScopeRow;
        if (scope_row != null &&
            scope_row.kind == ScopeKind.ACCOUNT &&
            (previous_scope == null || previous_scope.kind != ScopeKind.ACCOUNT)) {
            row.set_header(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));
        } else {
            row.set_header(null);
        }
    }

    private int sort_scope_rows(Gtk.ListBoxRow first, Gtk.ListBoxRow second) {
        ScopeRow? first_scope = first as ScopeRow;
        ScopeRow? second_scope = second as ScopeRow;
        if (first_scope == null || second_scope == null) {
            return 0;
        }

        if (first_scope.kind != second_scope.kind) {
            return scope_kind_sort_key(first_scope.kind) -
                scope_kind_sort_key(second_scope.kind);
        }

        if (first_scope.kind == ScopeKind.ACCOUNT) {
            return Geary.AccountInformation.compare_ascending(
                first_scope.source_account.information,
                second_scope.source_account.information
            );
        }

        return 0;
    }

    private int scope_kind_sort_key(ScopeKind kind) {
        switch (kind) {
        case LIST_ALL:
            return 0;

        case UNIFIED:
            return 1;

        case ACCOUNT:
            return 2;

        default:
            assert_not_reached();
        }
    }

}
