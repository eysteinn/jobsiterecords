-- Allow photo annotation overlay JSON and flattened render (§6.4a).
ALTER TABLE media_files DROP CONSTRAINT media_files_role_check;

ALTER TABLE media_files ADD CONSTRAINT media_files_role_check
  CHECK (role IN (
    'primary_photo',
    'voice_note',
    'attachment',
    'file',
    'annotation_overlay',
    'annotated_render'
  ));
