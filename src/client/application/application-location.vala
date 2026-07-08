/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Describes the conversation source currently selected in the main window. */
internal class Application.Location : Geary.BaseObject {

    public enum Kind {
        NONE,
        FOLDER,
        UNIFIED_SPECIAL_FOLDER
    }

    public Kind kind { get; private set; default = Kind.NONE; }

    public Geary.Folder? folder { get; private set; default = null; }

    public Geary.Folder.SpecialUse special_use {
        get; private set; default = Geary.Folder.SpecialUse.NONE;
    }

    public bool is_virtual {
        get { return this.kind == Kind.UNIFIED_SPECIAL_FOLDER; }
    }

    public Location.none() {
        this.kind = Kind.NONE;
    }

    public Location.for_folder(Geary.Folder folder) {
        this.kind = Kind.FOLDER;
        this.folder = folder;
    }

    public Location.unified_special_folder(Geary.Folder.SpecialUse special_use) {
        assert(supports_unified_special_folder(special_use));
        this.kind = Kind.UNIFIED_SPECIAL_FOLDER;
        this.special_use = special_use;
    }

    public bool is_folder(Geary.Folder folder) {
        return this.kind == Kind.FOLDER && this.folder == folder;
    }

    public bool is_unified_special_folder(Geary.Folder.SpecialUse special_use) {
        return this.kind == Kind.UNIFIED_SPECIAL_FOLDER &&
            this.special_use == special_use;
    }

    public Geary.Folder? get_operation_source(
        Geary.App.Conversation conversation
    ) {
        return this.is_virtual ? conversation.base_folder : this.folder;
    }

    public static bool supports_unified_special_folder(
        Geary.Folder.SpecialUse special_use
    ) {
        switch (special_use) {
        case INBOX:
        case DRAFTS:
        case SENT:
        case FLAGGED:
        case IMPORTANT:
        case ALL_MAIL:
        case ARCHIVE:
        case JUNK:
        case TRASH:
        case OUTBOX:
            return true;

        default:
            return false;
        }
    }

}
