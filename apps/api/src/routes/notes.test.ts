import assert from "node:assert/strict";
import test from "node:test";
import { canLinkRelatedTask, noteSchema } from "./notes.js";

test("note input trims content and supports an optional related task", () => {
  const note = noteSchema.parse({
    Title: "  Lecture notes  ",
    Content: "  Review chapter 2  ",
    RelatedTaskId: "  task-1  ",
  });

  assert.equal(note.Title, "Lecture notes");
  assert.equal(note.Content, "Review chapter 2");
  assert.equal(note.RelatedTaskId, "task-1");
  assert.equal(noteSchema.parse({ Title: "Notes", Content: "Text" }).RelatedTaskId, undefined);
});

test("note input rejects blank text and task links must belong to the same user", () => {
  const validNote = { Title: "Notes", Content: "Text" };

  assert.equal(noteSchema.safeParse({ ...validNote, Title: "   " }).success, false);
  assert.equal(noteSchema.safeParse({ ...validNote, Content: "   " }).success, false);
  assert.equal(noteSchema.safeParse({ ...validNote, RelatedTaskId: "   " }).success, false);
  assert.equal(canLinkRelatedTask("task-owner", "task-owner"), true);
  assert.equal(canLinkRelatedTask("other-user", "task-owner"), false);
  assert.equal(canLinkRelatedTask(undefined, "task-owner"), false);
});