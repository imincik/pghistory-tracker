BEGIN;
	DROP FUNCTION HT_Log();
	DROP FUNCTION HT_Log(text, text);
	DROP FUNCTION HT_Tag(text, text, text);
	DROP FUNCTION HT_Drop(text, text);
	DROP FUNCTION HT_Init(text, text);
	DROP FUNCTION _HT_CreateDiffType(text, text);
	DROP FUNCTION _HT_TableExists(text, text);
	DROP FUNCTION _HT_GetTablePkey(text, text);
	DROP FUNCTION _HT_GetTableFields(text, text);
	DROP FUNCTION HT_Version();
END;

-- vim: set ts=4 sts=4 sw=4 noet:
