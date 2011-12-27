BEGIN;
	DROP TABLE history_tracker.tags;
	DROP FUNCTION _HT_NextTagValue(text, text);
	DROP SCHEMA history_tracker;
END;

-- vim: set ts=4 sts=4 sw=4 noet:
