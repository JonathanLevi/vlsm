From stdpp Require Import prelude.
From Coq Require Import FinFun.
From VLSM Require Import Lib.Preamble Lib.ListExtras.
From VLSM Require Import Core.VLSM Core.VLSMProjections Core.Composition Core.ProjectionTraces Core.SubProjectionTraces.
From VLSM Require Import Core.Equivocation Core.EquivocationProjections Core.Equivocation.FixedSetEquivocation Core.Equivocation.NoEquivocation.
From VLSM Require Import Core.Equivocators.Common Core.Equivocators.Projections.
From VLSM Require Import Core.Equivocators.MessageProperties.
From VLSM Require Import Core.Equivocators.Composition.Common.
From VLSM Require Import Core.Equivocators.Composition.Projections.
From VLSM Require Import Core.Equivocators.Composition.SimulatingFree.FullReplayTraces.
From VLSM Require Import Core.Equivocators.Composition.LimitedEquivocation.FixedEquivocation.
From VLSM Require Import Core.Equivocators.Composition.SimulatingFree.SimulatingFree.

(** * VLSM Equivocators Simulating fixed-set equivocation composition

In this module we show that the composition of equivocators with no
message-equivocation and fixed-set state-equivocation can simulate the
fixed-set message-equivocation composition of regular nodes.

The proof is based on [generalized_equivocators_finite_valid_trace_init_to_rev],
but also reuses [seeded_equivocators_finite_valid_trace_init_to_rev] to
lift a trace of the free subcomposition of equivocating nodes generating a
message (given by the fixed message-equivocation constraint) to a trace of the
subcomposition of equivocating equivocators with no message-equivocation,
which is then used to satisfy the [replayable_message_prop]erty.
*)

Section fixed_equivocating.

Context {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (Free := free_composite_vlsm IM)
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (equivocating : list index)
  (X : VLSM message := strong_fixed_equivocation_vlsm_composition IM Hbs equivocating)
  (XE : VLSM message := equivocators_fixed_equivocations_vlsm IM Hbs index_listing equivocating)
  (FreeE := free_composite_vlsm (equivocator_IM IM))
  (PreFreeE := pre_loaded_with_all_messages_vlsm FreeE)
  (SubFreeE := free_composite_vlsm (sub_IM (equivocator_IM IM) equivocating))
  (Free_Hbs := free_composite_HasBeenSentCapability IM finite_index Hbs)
  (FreeE_Hbs := free_composite_HasBeenSentCapability (equivocator_IM IM) finite_index (equivocator_Hbs IM Hbs))
  (SubFreeE_Hbs := free_composite_HasBeenSentCapability (sub_IM (equivocator_IM IM) equivocating) (finite_sub_index equivocating finite_index) (sub_has_been_sent_capabilities (equivocator_IM IM) equivocating (equivocator_Hbs IM Hbs)))
  (no_initial_messages_in_IM : no_initial_messages_in_IM_prop IM)
  .

Existing Instance Free_Hbs.
Existing Instance FreeE_Hbs.
Existing Instance SubFreeE_Hbs.

Lemma no_initial_messages_in_sub_IM
  : forall i m, ~vinitial_message_prop (sub_IM IM equivocating i) m.
Proof.
  intros [i Hi] m Hinit.
  apply (no_initial_messages_in_IM i m).
  assumption.
Qed.

(** Messages [sent_by_non_equivocating] nodes in the projection of a valid
state for the fixed-set state-equivocation composition of equivocators with no
message-equivocation are valid for that composition of equivocators.
*)
Lemma fixed_equivocating_messages_sent_by_non_equivocating_are_valid
  eqv_state_s
  (Heqv_state_s : valid_state_prop XE eqv_state_s)
  (s := equivocators_total_state_project IM eqv_state_s)
  (Hs : valid_state_prop X s)
  m
  (Hm : sent_by_non_equivocating IM Hbs equivocating s m)
  : valid_message_prop XE m.
Proof.
  specialize (equivocators_fixed_equivocations_vlsm_incl_PreFree IM Hbs index_listing equivocating)
    as HinclE.
  apply sent_by_non_equivocating_are_sent in Hm.
  specialize (StrongFixed_incl_Preloaded IM Hbs equivocating)
    as Hincl.
  apply (VLSM_incl_valid_state Hincl) in Hs.
  apply
    (composite_sent_valid (equivocator_IM IM) finite_index (equivocator_Hbs IM Hbs)
      _ _ Heqv_state_s).
  revert Hm.
  apply (VLSM_incl_valid_state HinclE) in Heqv_state_s.
  by specialize
    (VLSM_projection_has_been_sent_reflect
      (preloaded_equivocators_no_equivocations_vlsm_X_vlsm_projection IM Hbs finite_index)
      _ Heqv_state_s m).
Qed.

(** This is the constraint counterpart of the [weak_full_projection_valid_preservation]
property (for the [equivocators_fixed_equivocations_constraint]).
 *)
Lemma fixed_equivocating_non_equivocating_constraint_lifting
  eqv_state_s
  (Heqv_state_s : valid_state_prop XE eqv_state_s)
  l s om
  (Hv :
    input_valid
      (seeded_equivocators_no_equivocation_vlsm IM Hbs equivocating
        (sent_by_non_equivocating IM Hbs equivocating (equivocators_total_state_project IM eqv_state_s)))
        l (s, om))
  (Hlift_s : valid_state_prop XE (lift_equivocators_sub_state_to IM equivocating eqv_state_s s))
  : equivocators_fixed_equivocations_constraint IM Hbs index_listing
        equivocating
        (lift_equivocators_sub_label_to IM equivocating eqv_state_s l)
        (lift_equivocators_sub_state_to IM equivocating eqv_state_s s, om).
Proof.
  specialize (equivocators_fixed_equivocations_vlsm_incl_PreFree IM Hbs index_listing equivocating)
    as HinclE.
  destruct Hv as [Hs [Hom [_ Hc]]].
  apply valid_state_has_fixed_equivocation in Hlift_s.
  split.
  - split; [|exact I].
    destruct om as [m|]; [|exact I].
    left.
    apply proj1 in Hc as [Hsent | Hseed].
    + revert Hsent. simpl.
      apply (VLSM_incl_valid_state HinclE) in Heqv_state_s.
      apply (VLSM_incl_valid_state (seeded_no_equivocation_incl_preloaded IM Hbs equivocating _)) in Hs.
      by specialize
        (VLSM_weak_full_projection_has_been_sent
          (PreFreeSubE_PreFreeE_weak_full_projection IM _ finite_index equivocating
            _ Heqv_state_s)
          _ Hs m
          ).
    + destruct Hseed as [i [Hi Hsent]].
      simpl.
      exists i.
      unfold lift_equivocators_sub_state_to.
      case_decide; [contradiction|].
      unfold equivocator_IM.
      change (equivocators_total_state_project _ _ _) with (equivocator_state_zero (eqv_state_s i)) in Hsent.
      revert Hsent.
      apply
        (VLSM_projection_has_been_sent_reflect
          (preloaded_equivocator_zero_projection (IM i)) (HbsX := equivocator_HasBeenSentCapability (IM i))).
      apply (VLSM_incl_valid_state HinclE) in Heqv_state_s.
      revert Heqv_state_s.
      apply (VLSM_projection_valid_state (preloaded_component_projection (equivocator_IM IM) i)).
  - destruct (composite_transition _ _ _) as (s', om') eqn:Ht'.
    apply
      (equivocating_transition_preserves_fixed_equivocation
        IM _ finite_index equivocating _ _ _ _ _ Ht' Hlift_s).
    destruct l as (sub_i, li).
    destruct_dec_sig sub_i i Hi Hsub_i.
    by subst.
Qed.

(** A message that can be generated from a state <<s>> of the free composition
  of equivocating equivocators pre-loaded with all messages has the
  [composite_has_been_sent] property for the state obtained upon "appending"
  state <<s>> to valid state for the composition of all equivocators.

  This result plays an important role in satisfying the no-message equivocation
  constraint.
*)
Lemma fixed_equivocation_replay_has_message
  eqv_state_s
  (Heqv_state_s : valid_state_prop PreFreeE eqv_state_s)
  im s
  (Him :
    can_produce
    (pre_loaded_with_all_messages_vlsm
      (free_composite_vlsm (equivocator_IM (sub_IM IM equivocating))))
    s im)
  : composite_has_been_sent (equivocator_IM IM) (equivocator_Hbs IM Hbs)
      (lift_equivocators_sub_state_to IM equivocating eqv_state_s s) im.
Proof.
  apply non_empty_valid_trace_from_can_produce in Him
    as [im_eis [im_etr [item [Him_etr [Hlast [Heqs Him]]]]]].
  specialize
    (PreFreeSubE_PreFreeE_weak_full_projection IM index_listing finite_index
      equivocating _ Heqv_state_s)
    as Hproj.
  pose
    (Hbs_sub_eqv := composite_HasBeenSentCapability
      (sub_IM (equivocator_IM IM) equivocating)
      (finite_sub_index equivocating finite_index)
      (sub_has_been_sent_capabilities (equivocator_IM IM) equivocating (equivocator_Hbs IM Hbs))
      (free_constraint _)).
  apply valid_trace_add_default_last in Him_etr.
  apply valid_trace_last_pstate in Him_etr as Him_etr_lst.
  specialize
    (VLSM_weak_full_projection_has_been_sent Hproj _ Him_etr_lst im) as Hsent.
  unfold has_been_sent in Hsent. simpl in Hsent.
  replace s with (finite_trace_last im_eis im_etr).
  - apply Hsent.
    apply
      (has_been_sent_examine_one_trace Hbs_sub_eqv _ _ _ Him_etr im).
    apply Exists_exists. exists item. split; [|assumption].
    apply elem_of_list_lookup.
    rewrite StdppExtras.last_last_error in Hlast.
    replace (Some _) with (last im_etr).
    clear. (* TODO: replace with stdpp.list.last_lookup once it becomes available *)
    exists (pred (length im_etr)).
    by induction im_etr as [| ?[]].
  - apply last_error_destination_last.
    rewrite Hlast. simpl. by f_equal.
Qed.

(** Messages satisfying the [strong_fixed_equivocation_constraint] have the
[replayable_message_prop]erty for the [equivocators_fixed_equivocations_constraint].
*)
Lemma fixed_equivocation_has_replayable_message_prop
  : replayable_message_prop IM Hbs (λ _ : message, False)
    (strong_fixed_equivocation_constraint IM Hbs equivocating)
    (equivocators_fixed_equivocations_constraint IM Hbs index_listing equivocating).
Proof.
  specialize (vlsm_is_pre_loaded_with_False XE) as HeqXE.
  specialize (vlsm_is_pre_loaded_with_False X) as HeqX.
  specialize (equivocators_fixed_equivocations_vlsm_incl_PreFree IM Hbs index_listing equivocating) as HinclE.
  intro; intros.
  destruct iom as [im|]; swap 1 2; [|destruct HcX as [Hsent | Hemitted]].
  - exists []. exists eqv_state_s.
    split; [constructor; assumption|].
    split; [reflexivity|].
    split; [assumption|].
    exact I.
  - exists []. exists eqv_state_s.
    split; [constructor; assumption|].
    split; [reflexivity|].
    split; [assumption|].
    apply sent_by_non_equivocating_are_sent in Hsent.
    apply (VLSM_eq_valid_state HeqXE) in Hstate_valid.
    apply (VLSM_incl_valid_state HinclE) in Hstate_valid.
    left.
    revert Hsent. subst.
    specialize
      (VLSM_projection_has_been_sent_reflect
        (preloaded_equivocators_no_equivocations_vlsm_X_vlsm_projection IM Hbs finite_index)
        eqv_state_s Hstate_valid im) as Hsent.
    unfold has_been_sent in Hsent. simpl in Hsent.
    assumption.
  - (*  If <<im>> can be emitted by the free composition of equivocating nodes
        seeded with the messages [sent_by_non_equivocating] in <<s>>, then we can
        use Lemma [seeded_equivocators_finite_valid_trace_init_to_rev] to
        simulate that trace in the equivocator-composition of equivocating
        nodes with no-messages equivocation.
    *)
    apply can_emit_has_trace in Hemitted
        as [im_is [im_tr [im_item [Him_tr Him_item]]]].
    apply valid_trace_add_default_last in Him_tr.
    rewrite finite_trace_last_is_last in Him_tr.
    apply
      (seeded_equivocators_finite_valid_trace_init_to_rev
        (sub_IM IM equivocating) (sub_has_been_sent_capabilities IM equivocating Hbs)
        (finite_sub_index equivocating finite_index) _ no_initial_messages_in_sub_IM)
      in Him_tr
      as [im_eis [Him_eis [im_es [Him_es [im_etr [Him_etr_pr [Him_etr Him_output]]]]]]].
    rewrite finite_trace_last_output_is_last in Him_output.
    rewrite Him_item in Him_output.
    (*  We will use Lemma
        [sub_preloaded_replayed_trace_from_valid_equivocating] to replay
        the trace obtained above on top of the given state, thus ensuring that
        state-equivocation is only introduced for the equivocating nodes.
        We will used Lemmas [fixed_equivocating_messages_sent_by_non_equivocating_are_valid]
        and [fixed_equivocating_non_equivocating_constraint_lifting] to satisfy
        the hypotheses of the replay lemma.
    *)
    specialize
      (sub_preloaded_replayed_trace_from_valid_equivocating
        IM Hbs _ finite_index (sent_by_non_equivocating IM Hbs equivocating s)
        equivocating
        (equivocators_fixed_equivocations_constraint IM Hbs index_listing equivocating)
        (fun m => False))
      as Hreplay.
    spec Hreplay.
    { clear -finite_index HeqXE. intros i ns s Hi Hs.
      split; [split; exact I|].
      apply (VLSM_eq_valid_state HeqXE) in Hs.
      apply valid_state_has_fixed_equivocation in Hs.
      destruct (composite_transition _ _ _) as (s', om') eqn:Ht.
      apply
        (equivocating_transition_preserves_fixed_equivocation
          IM _ finite_index equivocating _ _ _ _ _ Ht Hs).
      assumption.
    }
    spec Hreplay.
    { subst s.
      apply valid_trace_last_pstate in HtrX.
      apply (VLSM_eq_valid_state HeqXE) in Hstate_valid.
      apply (VLSM_eq_valid_state HeqX) in HtrX.
      intros m Hsent.
      apply (VLSM_incl_valid_message (VLSM_eq_proj1 HeqXE)); [by left|].
      by apply (fixed_equivocating_messages_sent_by_non_equivocating_are_valid eqv_state_s).
    }
    spec Hreplay eqv_state_s.
    spec Hreplay.
    { by apply (VLSM_eq_valid_state HeqXE), (VLSM_eq_valid_state HeqXE). }
    spec Hreplay.
    { subst s.
      clear -finite_index FreeE_Hbs SubFreeE_Hbs HeqXE Hstate_valid.
      intros l s om Hv Hlift_s.
      apply (VLSM_eq_valid_state HeqXE) in Hstate_valid.
      apply (VLSM_eq_valid_state HeqXE) in Hlift_s.
      by apply fixed_equivocating_non_equivocating_constraint_lifting.
    }
    apply valid_trace_get_last in Him_etr as Him_etr_lst.
    apply valid_trace_forget_last in Him_etr.
    specialize (Hreplay _ _ Him_etr).
    apply valid_trace_add_default_last in Hreplay.
    eexists _,_; split; [exact Hreplay|].
    (*  Having verified the validity part of the conclusion, now we only
        need to show two projection properties, and the no message-equivocation
        constraint for which we employ Lemma [fixed_equivocation_replay_has_message].
    *)
    repeat split.
    + apply
      (equivocators_total_trace_project_replayed_trace_from
        IM index_listing equivocating
        eqv_state_s im_eis im_etr).
    + subst s.
      apply
      (equivocators_total_state_project_replayed_trace_from
        IM index_listing equivocating
        eqv_state_s im_eis im_etr).
    +
      apply (VLSM_eq_valid_state HeqXE) in Hstate_valid.
      apply (VLSM_incl_valid_state HinclE) in Hstate_valid as Hstate_pre.
      specialize
        (NoEquivocation.seeded_no_equivocation_incl_preloaded (equivocator_IM (sub_IM IM equivocating))
          (free_constraint _)
          (sub_has_been_sent_capabilities (equivocator_IM IM) equivocating (equivocator_Hbs IM Hbs))
          (sent_by_non_equivocating IM Hbs equivocating
                    s)
        ) as Hsub_incl.
      apply (VLSM_incl_finite_valid_trace Hsub_incl) in Him_etr.
      left.
      specialize
        (replayed_trace_from_finite_trace_last IM _ finite_index equivocating eqv_state_s im_eis im_etr (proj2 Him_etr)).
      simpl. intro Hrew. rewrite Hrew. clear Hrew.
      apply fixed_equivocation_replay_has_message; [assumption|].
      clear -Him_etr Him_output.
      destruct_list_last im_etr im_ert' item Heqim_etr; [inversion Him_output|].
      apply proj1 in Him_etr.
      replace (im_ert' ++ [item]) with (im_ert' ++ [item] ++ []) in Him_etr
        by (rewrite app_assoc; apply app_nil_r).
      specialize
        (input_valid_transition_to
          (pre_loaded_with_all_messages_vlsm (free_composite_vlsm (equivocator_IM (sub_IM IM equivocating))))
          _ _ _ _ _ Him_etr eq_refl)
        as Ht.
      rewrite finite_trace_last_is_last.
      rewrite finite_trace_last_output_is_last in Him_output.
      replace (output _) with (Some im) in Ht.
      eexists _,_; exact Ht.
Qed.

(** ** The main result

The main result, showing that fixed-set message-equivocation traces can be
simulated by fixed-set state-equivocation traces is obtained by instantiating
Lemma [generalized_equivocators_finite_valid_trace_init_to_rev], discharing
the most complex assumption of the lemma (about [replayable_message_prop])
with Lemma [fixed_equivocation_has_replayable_message_prop].
*)
Lemma fixed_equivocators_finite_valid_trace_init_to_rev
  isX sX trX
  (HtrX : finite_valid_trace_init_to X isX sX trX)
  : exists is, equivocators_total_state_project IM is = isX /\
    exists s, equivocators_total_state_project IM s = sX /\
    exists tr, equivocators_total_trace_project IM tr = trX /\
    finite_valid_trace_init_to XE is s tr /\
    finite_trace_last_output trX = finite_trace_last_output tr.
Proof.
  (*
  Since the base result works with pre-loaded vlsms, some massaging of the
  hypothesis and conclusion is done to fit the applied lemma.
  *)
  assert (no_initial_messages_in_XE : forall m, ~vinitial_message_prop (pre_loaded_vlsm XE (fun _ => False)) m).
  { intros m [[i [[mi Hmi] Him]]|Hseeded]; [|contradiction].
    elim (no_initial_messages_in_IM i mi).
    assumption.
  }
  specialize (vlsm_is_pre_loaded_with_False X) as HeqX.
  specialize (vlsm_is_pre_loaded_with_False XE) as HeqXE.
  apply (VLSM_eq_finite_valid_trace_init_to HeqX) in HtrX.
  apply
    (generalized_equivocators_finite_valid_trace_init_to_rev
      IM Hbs finite_index _ _
      (equivocators_fixed_equivocations_constraint IM Hbs index_listing equivocating))
    in HtrX
    as [is [His [s [Hs [tr [Htr [Hptr Houtput]]]]]]].
  - exists is. split; [assumption|].
    exists s. split; [assumption|].
    exists tr. split; [assumption|].
    split; [|assumption].
    apply (VLSM_eq_finite_valid_trace_init_to HeqXE).
    assumption.
  - intro; intros.
    apply (VLSM_eq_valid_state HeqXE) in Hes.
    split.
    + split; [|exact I].  destruct om as [im|]; [|exact I].
      destruct Hom as [Hom|Hinitial]; [left; assumption|exfalso].
      apply no_initial_messages_in_XE in Hinitial. contradiction.
    + apply valid_state_has_fixed_equivocation in Hes.
      destruct (composite_transition _ _ _) as (es', om') eqn:Het.
      simpl.
      apply
        (zero_descriptor_transition_preserves_fixed_equivocation
          IM _ finite_index equivocating _ _ _ _ _ Het Hes li
        ).
      reflexivity.
  - apply fixed_equivocation_has_replayable_message_prop.
Qed.

End fixed_equivocating.

(** ** No-equivocation simulation as a particular case of fixed-set simulation

In this section we show that traces of the composition of nodes  with no
message-equivocation can be simulated by the composition of equivocators with
no message-equivocation in which no component is allowed to state-equivocate.
*)

Section no_equivocation.

Context {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  {i0 : Inhabited index}
  (Free := free_composite_vlsm IM)
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (X : VLSM message := composite_vlsm IM (composite_no_equivocations IM Hbs))
  (XE : VLSM message := equivocators_fixed_equivocations_vlsm IM Hbs index_listing [])
  (FreeE := free_composite_vlsm (equivocator_IM IM))
  (PreFreeE := pre_loaded_with_all_messages_vlsm FreeE)
  (Free_Hbs := free_composite_HasBeenSentCapability IM finite_index Hbs)
  (FreeE_Hbs := free_composite_HasBeenSentCapability (equivocator_IM IM) finite_index (equivocator_Hbs IM Hbs))
  .

Existing Instance Free_Hbs.
Existing Instance FreeE_Hbs.

Lemma no_equivocating_equivocators_finite_valid_trace_init_to_rev
  (no_initial_messages_in_IM : no_initial_messages_in_IM_prop IM)
  isX sX trX
  (HtrX : finite_valid_trace_init_to X isX sX trX)
  : exists is, equivocators_total_state_project IM is = isX /\
    exists s, equivocators_total_state_project IM s = sX /\
    exists tr, equivocators_total_trace_project IM tr = trX /\
    finite_valid_trace_init_to XE is s tr /\
    finite_trace_last_output trX = finite_trace_last_output tr.
Proof.
  assert (no_initial_messages_in_XE : forall m, ~vinitial_message_prop (pre_loaded_vlsm XE (fun _ => False)) m).
  {
    intros m [[i [[mi Hmi] Him]]|Hseeded]; [|contradiction].
    elim (no_initial_messages_in_IM i mi).
    assumption.
  }
  specialize (vlsm_is_pre_loaded_with_False X) as HeqX.
  specialize (vlsm_is_pre_loaded_with_False XE) as HeqXE.
  apply (VLSM_eq_finite_valid_trace_init_to HeqX) in HtrX.
  apply
    (generalized_equivocators_finite_valid_trace_init_to_rev
      IM Hbs finite_index _ _
      (equivocators_fixed_equivocations_constraint IM Hbs index_listing []))
    in HtrX
    as [is [His [s [Hs [tr [Htr [Hptr Houtput]]]]]]].
  - exists is. split; [assumption|].
    exists s. split; [assumption|].
    exists tr. split; [assumption|].
    split; [|assumption].
    apply (VLSM_eq_finite_valid_trace_init_to HeqXE).
    assumption.
  - intro; intros.
    apply (VLSM_eq_valid_state HeqXE) in Hes.
    split.
    + split; [|exact I].  destruct om as [im|]; [|exact I].
      destruct Hom as [Hom|Hinitial]; [left; assumption|exfalso].
      apply no_initial_messages_in_XE in Hinitial. contradiction.
    + apply valid_state_has_fixed_equivocation in Hes.
      destruct (composite_transition _ _ _) as (es', om') eqn:Het.
      simpl.
      apply
        (zero_descriptor_transition_preserves_fixed_equivocation
          IM _ finite_index [] _ _ _ _ _ Het Hes li
        ).
      reflexivity.
  - clear isX sX trX HtrX. intro; intros.
    specialize (equivocators_fixed_equivocations_vlsm_incl_PreFree IM Hbs index_listing []) as HinclE.
    destruct iom as [im|].
    2: {
      exists []. exists eqv_state_s.
      split; [constructor; assumption|].
      split; [reflexivity|].
      split; [assumption|exact I].
    }
    destruct HcX as [Hsent | Hemitted]; [|contradiction].
    exists []. exists eqv_state_s.
    split; [constructor; assumption|].
    split; [reflexivity|].
    split; [assumption|].
    apply (VLSM_eq_valid_state HeqXE) in Hstate_valid.
    apply (VLSM_incl_valid_state HinclE) in Hstate_valid.
    left.
    revert Hsent. subst.
    specialize
      (VLSM_projection_has_been_sent_reflect
        (preloaded_equivocators_no_equivocations_vlsm_X_vlsm_projection IM Hbs finite_index)
        eqv_state_s Hstate_valid im) as Hsent.
    unfold has_been_sent in Hsent. simpl in Hsent.
    assumption.
Qed.

End no_equivocation.
