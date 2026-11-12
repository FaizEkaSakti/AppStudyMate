import assert from "node:assert/strict";
import test from "node:test";
import { profileSchema } from "./profile.js";

test("profile input trims identity fields and normalizes email", () => {
  const profile = profileSchema.parse({
    Name: "  Ani Putri  ",
    Email: "  ANI@EXAMPLE.COM ",
    Nim: "  123456  ",
  });

  assert.deepEqual(profile, {
    Name: "Ani Putri",
    Email: "ani@example.com",
    Nim: "123456",
  });
});

test("profile input rejects short identity fields and invalid email", () => {
  const validProfile = {
    Name: "Ani",
    Email: "ani@example.com",
    Nim: "123",
  };

  assert.equal(profileSchema.safeParse({ ...validProfile, Name: " " }).success, false);
  assert.equal(profileSchema.safeParse({ ...validProfile, Email: "invalid" }).success, false);
  assert.equal(profileSchema.safeParse({ ...validProfile, Nim: "12" }).success, false);
});
