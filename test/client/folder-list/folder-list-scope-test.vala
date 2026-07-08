/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class FolderList.ScopeTest : TestCase {

    public ScopeTest() {
        base("FolderList.ScopeTest");
        add_test("list_all", list_all);
        add_test("account", account);
        add_test("unified", unified);
        add_test("equality", equality);
    }

    public void list_all() throws GLib.Error {
        Scope scope = new Scope.list_all();

        assert(scope.kind == Scope.Kind.LIST_ALL);
        assert(scope.account == null);
        assert(scope.is_list_all);
        assert(!scope.is_account);
        assert(!scope.is_unified);
        assert_equal(scope.get_display_name(), "All Account Folders");
    }

    public void account() throws GLib.Error {
        Geary.Account account = new_account("work", "Work Mail");
        Scope scope = new Scope.for_account(account);

        assert(scope.kind == Scope.Kind.ACCOUNT);
        assert(scope.account == account);
        assert(!scope.is_list_all);
        assert(scope.is_account);
        assert(!scope.is_unified);
        assert_equal(scope.get_display_name(), "Work Mail");
    }

    public void unified() throws GLib.Error {
        Scope scope = new Scope.unified();

        assert(scope.kind == Scope.Kind.UNIFIED);
        assert(scope.account == null);
        assert(!scope.is_list_all);
        assert(!scope.is_account);
        assert(scope.is_unified);
        assert_equal(scope.get_display_name(), "All Accounts");
    }

    public void equality() throws GLib.Error {
        Geary.Account first = new_account("first", "First");
        Geary.Account second = new_account("second", "Second");

        assert(new Scope.list_all().equal_to(new Scope.list_all()));
        assert(new Scope.unified().equal_to(new Scope.unified()));
        assert(new Scope.for_account(first).equal_to(new Scope.for_account(first)));

        assert(!new Scope.list_all().equal_to(new Scope.unified()));
        assert(!new Scope.for_account(first).equal_to(new Scope.for_account(second)));
        assert(!new Scope.for_account(first).equal_to(new Scope.list_all()));
    }

    private Geary.Account new_account(string id, string label) {
        Geary.AccountInformation info = new Geary.AccountInformation(
            id,
            OTHER,
            new Mock.CredentialsMediator(),
            new Geary.RFC822.MailboxAddress(id, "%s@example.com".printf(id))
        );
        info.label = label;
        return new Mock.Account(info);
    }

}
