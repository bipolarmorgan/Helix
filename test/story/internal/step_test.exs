defmodule Helix.Story.Internal.StepTest do

  use Helix.Test.Case.Integration

  alias Helix.Story.Model.Story
  alias Helix.Story.Internal.Step, as: StepInternal

  alias Helix.Test.Entity.Helper, as: EntityHelper
  alias Helix.Test.Story.Helper, as: StoryHelper
  alias Helix.Test.Story.Setup, as: StorySetup

  describe "fetch_step/2" do
    test "returns the step" do
      {story_step, %{step: step}} = StorySetup.story_step()

      %{object: object, entry: entry} =
        StepInternal.fetch_step(story_step.entity_id, step.contact)

      assert entry == story_step
      assert object == step
    end

    test "formats the step meta using `format_meta/1` from Steppable" do
      {story_step, %{step: step}} =
        StorySetup.story_step(
          name: :fake_steps@test_meta,
          meta: %{foo: :bar, id: EntityHelper.id()}
        )

      %{entry: entry} =
        StepInternal.fetch_step(story_step.entity_id, step.contact)

      assert entry == story_step
      assert entry.meta.foo == :bar
    end

    test "returns nil when entity isn't part of any step" do
      refute \
        StepInternal.fetch_step(EntityHelper.id(), StoryHelper.contact_id())
    end
  end

  describe "get_steps/1" do
    test "returns all steps the user is currently in" do
      {story_step1, %{step: step1}} =
        StorySetup.story_step(
          name: :fake_contact_one@test_simple,
          meta: %{}
        )
      {story_step2, %{step: step2}} =
        StorySetup.story_step(
          entity_id: step1.entity_id,
          name: :fake_contact_two@test_simple,
          meta: %{}
        )

      assert [info1, info2] = StepInternal.get_steps(step1.entity_id)

      assert info1.object == step1
      assert info1.entry == story_step1
      assert info2.object == step2
      assert info2.entry == story_step2
    end

    test "returns empty list when not found" do
      assert Enum.empty?(StepInternal.get_steps(EntityHelper.id()))
    end
  end

  describe "proceed/1 and proceed/2" do
    test "proceed/1 setups the first step" do
      entity_id = EntityHelper.id()
      {first_step, _} = StorySetup.step(entity_id: entity_id)

      # Not part of any step
      assert Enum.empty?(StepInternal.get_steps(entity_id))

      # Proceeds to the first step
      assert {:ok, story_step} = StepInternal.proceed(first_step)

      assert story_step.entity_id == entity_id
      assert story_step.step_name == first_step.name

      # Retrieve from DB
      [%{entry: db_entry}] = StepInternal.get_steps(entity_id)
      assert db_entry == story_step
    end

    test "removes the entity from the previous step, puts it into the next" do
      {prev_step, next_step, %{entity_id: entity_id}} =
        StorySetup.step_sequence()

      # Currently on `prev_step`
      assert [%{object: step_before}] = StepInternal.get_steps(entity_id)
      assert step_before == prev_step

      # Proceeds to the next step
      StepInternal.proceed(prev_step, next_step)

      # It proceeded to the next step
      [%{object: step_after}] = StepInternal.get_steps(entity_id)
      assert step_after == next_step

      # Make sure there's only one entry (the previous step was deleted)
      assert length(StoryHelper.get_steps_from_entity(entity_id)) == 1
    end
  end

  describe "update_meta/1" do
    test "step meta is overwritten" do
      {_, %{step: step, entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_steps@test_counter, meta: %{i: 0})

      # Current step has the original meta, as expected
      [%{entry: story_step0}] = StepInternal.get_steps(entity_id)
      assert story_step0.meta == %{i: 0}

      # Create a new step with a different meta
      new_step = %{step| meta: %{i: 1}}

      # Persist meta modification
      assert {:ok, _} = StepInternal.update_meta(new_step)

      # Ensure step meta changed
      [%{entry: story_step1}] = StepInternal.get_steps(entity_id)
      assert story_step1.meta == %{i: 1}

      # One more time!
      StepInternal.update_meta(%{step| meta: %{i: 2}})

      [%{entry: story_step2}] = StepInternal.get_steps(entity_id)
      assert story_step2.meta == %{i: 2}
    end

    test "raises if step is not found" do
      {step, _} = StorySetup.step()
      assert_raise Ecto.NoResultsError, fn ->
        StepInternal.update_meta(step)
      end
    end
  end

  describe "unlock_reply/2" do
    test "new reply is saved on the story_step, marked as unlocked" do
      {_, %{step: step, entity_id: entity_id}} = StorySetup.story_step()

      reply_id1 = "1st_reply"
      reply_id2 = "2nd_reply"

      # Mark as unlocked
      assert {:ok, new_entry1} = StepInternal.unlock_reply(step, reply_id1)
      assert new_entry1.allowed_replies == [reply_id1]

      # Ensure data on DB is correct
      %{entry: db_entry1, object: fetched_step} =
        StepInternal.fetch_step(entity_id, step.contact)
      assert fetched_step == step
      assert db_entry1.allowed_replies == [reply_id1]

      # Add another reply
      assert {:ok, new_entry2} = StepInternal.unlock_reply(step, reply_id2)
      assert new_entry2.allowed_replies == [reply_id1, reply_id2]

      # Ensure it got pushed into the list
      %{entry: db_entry2} = StepInternal.fetch_step(entity_id, step.contact)
      assert db_entry2.allowed_replies == [reply_id1, reply_id2]
    end

    test "repeated replies are not added to the database" do
      {_, %{step: step, entity_id: entity_id}} = StorySetup.story_step()

      reply_id = "my_repeated_reply"

      assert {:ok, _} = StepInternal.unlock_reply(step, reply_id)
      assert {:ok, _} = StepInternal.unlock_reply(step, reply_id)
      assert {:ok, _} = StepInternal.unlock_reply(step, reply_id)

      %{entry: db_entry} = StepInternal.fetch_step(entity_id, step.contact)
      assert db_entry.allowed_replies == [reply_id]
    end

    test "raises if step is not found" do
      {step, _} = StorySetup.step()
      assert_raise Ecto.NoResultsError, fn ->
        StepInternal.unlock_reply(step, "reply")
      end
    end
  end

  describe "lock_reply/2" do
    test "new reply is removed from story_step, marked as locked" do
      {entry, %{step: step, entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_steps@test_msg, meta: %{})

      allowed_before = Story.Step.get_allowed_replies(entry)
      reply_id = Enum.random(allowed_before)

      assert {:ok, _} = StepInternal.lock_reply(step, reply_id)
      %{entry: new_entry} = StepInternal.fetch_step(entity_id, step.contact)

      allowed_after = Story.Step.get_allowed_replies(new_entry)

      refute allowed_before == allowed_after
      assert length(allowed_after) == length(allowed_before) - 1
      refute Enum.member?(allowed_after, reply_id)
    end

    test "ignores if step is not found" do
      {entry, %{step: step, entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_steps@test_msg, meta: %{})

      allowed_before = Story.Step.get_allowed_replies(entry)
      reply_id = "i_do_not_exist"

      assert {:ok, _} = StepInternal.lock_reply(step, reply_id)
      %{entry: new_entry} = StepInternal.fetch_step(entity_id, step.contact)

      allowed_after = Story.Step.get_allowed_replies(new_entry)

      assert allowed_after == allowed_before
    end
  end

  describe "save_email/2" do
    test "new email is saved on the database" do
      {_, %{step: step, entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_steps@test_simple, meta: %{})

      email_id1 = "1st_email"
      email_id2 = "2nd_email"

      # Save first email
      assert {:ok, new_entry1} = StepInternal.save_email(step, email_id1)
      assert new_entry1.emails_sent == [email_id1]

      # Ensure data on DB is correct
      %{entry: db_entry1} = StepInternal.fetch_step(entity_id, step.contact)
      assert db_entry1.emails_sent == [email_id1]

      # Add another reply
      assert {:ok, new_entry2} = StepInternal.save_email(step, email_id2)
      assert new_entry2.emails_sent == [email_id1, email_id2]

      # Ensure it got pushed into the list
      %{entry: db_entry2} = StepInternal.fetch_step(entity_id, step.contact)
      assert db_entry2.emails_sent == [email_id1, email_id2]
    end

    test "repeated emails are pushed to the database as usual" do
      {_, %{step: step, entity_id: entity_id}} = StorySetup.story_step()

      email_id = "my_repeated_email"

      assert {:ok, _} = StepInternal.save_email(step, email_id)
      assert {:ok, _} = StepInternal.save_email(step, email_id)
      assert {:ok, _} = StepInternal.save_email(step, email_id)

      %{entry: db_entry} = StepInternal.fetch_step(entity_id, step.contact)
      assert db_entry.emails_sent == [email_id, email_id, email_id]
    end

    test "raises if step is not found" do
      {step, _} = StorySetup.step()
      assert_raise Ecto.NoResultsError, fn ->
        StepInternal.save_email(step, "email")
      end
    end
  end
end
