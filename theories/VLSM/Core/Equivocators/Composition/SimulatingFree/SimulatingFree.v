From stdpp Require Import prelude.
From Coq Require Import FinFun Lia FunctionalExtensionality.
From VLSM Require Import Lib.Preamble Lib.ListExtras Lib.FinExtras Lib.FinFunExtras.
From VLSM Require Import Core.VLSM Core.VLSMProjections Core.Composition Core.ProjectionTraces Core.SubProjectionTraces.
From VLSM Require Import Core.Equivocation Core.Equivocation.NoEquivocation.
From VLSM Require Import Core.Equivocators.Common Core.Equivocators.Projections.
From VLSM Require Import Core.Equivocators.MessageProperties.
From VLSM Require Import Core.Equivocators.Composition.Common.
From VLSM Require Import Core.Equivocators.Composition.Projections.
From VLSM Require Import Core.Equivocators.Composition.SimulatingFree.FullReplayTraces.
From VLSM Require Import Core.Equivocators.Composition.LimitedEquivocation.FixedEquivocation.
From VLSM Require Import Core.Plans.

(** * Equivocators simulating regular nodes

In this module we prove a general simulation result parameterized by
constraints with good properties, then we instantiate the general result for
the free composition of regular nodes.
*)

Section generalized_constraints.

(** ** Generic simulation

In this section we prove a general simulation result, namely that a composition
of equivocators constrained by a <<constraintE>> can simulate a composition of
the corresponding regular nodes constrained by a <<constraintX>> if they are
related through the [zero_descriptor_constraint_lifting_prop]erty and the
[replayable_message_prop].
*)

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  {index_listing : list index}
  (finite_index : Listing index_listing)

  (seed : message -> Prop)
  (constraintX : composite_label IM -> composite_state IM * option message -> Prop)
  (CX := pre_loaded_vlsm (composite_vlsm IM constraintX) seed)
  (constraintE : composite_label (equivocator_IM IM) -> composite_state (equivocator_IM IM) * option message -> Prop)
  (CE := pre_loaded_vlsm (composite_vlsm (equivocator_IM IM) constraintE) seed)

  (FreeE := free_composite_vlsm (equivocator_IM IM))
  (PreFreeE := pre_loaded_with_all_messages_vlsm FreeE)
  .

Definition last_in_trace_except_from {T} exception (tr : list (@transition_item message T)) iom : Prop :=
    match iom with
    | None => True
    | Some im =>
      finite_trace_last_output tr = Some im
      \/ exception im
    end.

(** A property requiring that <<constraintE>> holds for any transition using
an original copy of an equivocator if the message is initial or [has_been_sent]
for the given state.
*)
Definition zero_descriptor_constraint_lifting_prop : Prop :=
  forall
    es (Hes : valid_state_prop CE es)
    om (Hom : sent_except_from (equivocator_IM IM) (equivocator_Hbs IM Hbs) (vinitial_message_prop CE) es om)
    eqv li,
    constraintE (existT eqv (ContinueWith 0 li)) (es, om).

(** The [replayable_message_prop]erty plays an important role in designing a
general, abstract, proof for trace simulation (Lemma
[generalized_equivocators_finite_valid_trace_init_to_rev]), as it specifies
that given a message <<m>> received in a regular node-composition state <<s>>
for which the constraint <<constraintX>> is satisfied, then any trace of the
equivocators-composition (constrained by <<constraintE>>>) producing <<m>>
can be "replayed" on top of an equivocators-composition state corresponding
to <<s>>, with no transitions being performed on the original copies.
*)
Definition replayable_message_prop : Prop :=
  forall si s tr
    (HtrX : finite_valid_trace_init_to CX si s tr)
    eqv_state_s
    (Hstate_valid: valid_state_prop CE eqv_state_s)
    (Hstate_final_project : equivocators_total_state_project IM eqv_state_s = s)
    eqv_msg_is eqv_msg_s eqv_msg_tr
    (Hmsg_trace : finite_valid_trace_init_to CE eqv_msg_is eqv_msg_s eqv_msg_tr)
    iom
    (Hfinal_msg : last_in_trace_except_from (vinitial_message_prop CE) eqv_msg_tr iom)
    l
    (HcX: constraintX l (s, iom)),
    exists eqv_msg_tr lst_msg_tr,
      finite_valid_trace_from_to CE eqv_state_s lst_msg_tr eqv_msg_tr /\
      equivocators_total_trace_project IM eqv_msg_tr = [] /\
      equivocators_total_state_project IM lst_msg_tr = s /\
      sent_except_from (equivocator_IM IM) (equivocator_Hbs IM Hbs) (vinitial_message_prop CE) lst_msg_tr iom.

(** The main result of this section, showing that every trace of the
composition of regular nodes can be obtained as a [zero_descriptor] projection
of a valid trace for the composition of equivocators.

The proof proceeds by replaying the transitions of the trace on the original
copy of the machines, replaying traces corresponding to the messages between
those transition through equivocation to guarantee the no-message-equivocation
constraint.
*)
Lemma generalized_equivocators_finite_valid_trace_init_to_rev
  (Hsubsumption : zero_descriptor_constraint_lifting_prop)
  (Hreplayable : replayable_message_prop)
  isX sX trX
  (HtrX : finite_valid_trace_init_to CX isX sX trX)
  : exists is, equivocators_total_state_project IM is = isX /\
    exists s, equivocators_total_state_project IM s = sX /\
    exists tr, equivocators_total_trace_project IM tr = trX /\
    finite_valid_trace_init_to CE is s tr /\
    finite_trace_last_output trX = finite_trace_last_output tr.
Proof.
  assert (HinclE : VLSM_incl CE PreFreeE)
    by apply composite_pre_loaded_vlsm_incl_pre_loaded_with_all_messages.
  induction HtrX using finite_valid_trace_init_to_rev_strong_ind.
  - specialize (lift_initial_to_equivocators_state IM Hbs _ His) as Hs.
    remember (lift_to_equivocators_state IM is) as s.
    cut (equivocators_state_project IM (zero_descriptor IM) s = is).
    { intro Hproject.
      exists s. split; [exact Hproject|].
      exists s. split; [exact Hproject|].
      exists []. split; [reflexivity|].
      split; [|reflexivity].
      split; [|assumption].
      constructor.
      apply initial_state_is_valid. assumption.
    }
    apply functional_extensionality_dep_good.
    subst.
    reflexivity.
  - destruct IHHtrX1 as [eqv_state_is [Hstate_start_project [eqv_state_s [Hstate_final_project [eqv_state_tr [Hstate_project [Hstate_trace _ ]]]]]]].
    destruct IHHtrX2 as [eqv_msg_is [Hmsg_start_project [eqv_msg_s [_ [eqv_msg_tr [Hmsg_project [Hmsg_trace Hfinal_msg ]]]]]]].
    exists eqv_state_is. split; [assumption|].
    apply valid_trace_last_pstate in Hstate_trace as Hstate_valid.
    destruct Ht as [[Hs [Hiom [Hv Hc]]] Ht].
    specialize
      (Hreplayable _ _ _ HtrX1 _ Hstate_valid Hstate_final_project _ _ _ Hmsg_trace iom)
      as Hreplay.
    spec Hreplay.
    { clear -Heqiom Hfinal_msg.
      destruct iom as [im|]; [|exact I].
      unfold empty_initial_message_or_final_output in Heqiom.
      destruct_list_last iom_tr iom_tr' item Heqiom_tr.
      - right. assumption.
      - left. simpl in *. rewrite <- Hfinal_msg.
        rewrite finite_trace_last_output_is_last.
        assumption.
    }
    specialize (Hreplay _ Hc)
      as [emsg_tr [es [Hmsg_trace_full_replay [Hemsg_tr_pr [Hes_pr Hbs_iom]]]]].
    intros .
    specialize
      (finite_valid_trace_from_to_app CE  _ _ _ _ _ (proj1 Hstate_trace) Hmsg_trace_full_replay)
      as Happ.
    specialize
      (extend_right_finite_trace_from_to CE Happ) as Happ_extend.
    destruct l as (eqv, li).
    pose
      (@existT _ (fun i : index => vlabel (equivocator_IM IM i)) eqv (ContinueWith 0 li))
      as el.
    destruct (vtransition CE el (es, iom))
      as (es', om') eqn:Hesom'.
    specialize (Happ_extend  el iom es' om').
    apply valid_trace_get_last in Happ as Heqes.
    assert (Hes_pr_i : forall i, equivocators_total_state_project IM es i = s i)
      by (rewrite <- Hes_pr; reflexivity).
    exists es'.
    assert (Het := Hesom').
    specialize (Hes_pr_i eqv) as Hes_pr_eqv.
    cbn in Hesom', Hes_pr_eqv.
    rewrite equivocator_state_project_zero in Hesom', Hes_pr_eqv.
    cbn in Hesom', Hes_pr_eqv.
    rewrite Hes_pr_eqv in Hesom'.
    cbn in Ht.
    destruct (vtransition _ _ _) as (si', _om) eqn:Hteqv.
    inversion Ht. subst sf _om. clear Ht.
    inversion Hesom'. subst es' om'. clear Hesom'.
    match type of Happ_extend with
    | ?H -> _ => cut H
    end.
    { intro Hivt.
      spec Happ_extend Hivt.
      match goal with
      |- ?H /\ _ => assert (Hproject : H)
      end.
      { apply functional_extensionality_dep.
        intro i.
        unfold equivocators_total_state_project at 1.
        unfold equivocators_state_project.
        destruct (decide (i = eqv)).
        * subst. rewrite !state_update_eq. reflexivity.
        * rewrite !state_update_neq by congruence.
          simpl. apply Hes_pr_i.
      }
      split; [assumption|].
      eexists; split; [|split;[split; [exact Happ_extend|]|]].
      - apply valid_trace_forget_last in Happ_extend.
        apply (VLSM_incl_finite_valid_trace_from HinclE) in Happ_extend.
        rewrite (equivocators_total_trace_project_app IM)
          by (eexists; exact Happ_extend).
        apply valid_trace_forget_last in Happ.
        apply (VLSM_incl_finite_valid_trace_from HinclE) in Happ.
        rewrite (equivocators_total_trace_project_app IM)
          by (eexists; exact Happ).
        rewrite Hemsg_tr_pr.
        rewrite app_nil_r.
        rewrite Hstate_project.
        f_equal.
        subst el.
        unfold equivocators_total_trace_project.
        cbn. unfold equivocators_transition_item_project.
        cbn.
        rewrite !equivocator_state_project_zero.
        rewrite decide_True by reflexivity.
        simpl.
        repeat f_equal.
        assumption.
      - apply Hstate_trace.
      - rewrite! finite_trace_last_output_is_last. reflexivity.
    }
    clear Happ_extend.
    apply valid_trace_last_pstate in Happ.
    repeat split; [assumption|..|assumption].
    + destruct iom as [im|]; [|apply option_valid_message_None].
      destruct Hbs_iom as [Hbs_iom | Hseeded].
      * apply (preloaded_composite_sent_valid (equivocator_IM IM) finite_index (equivocator_Hbs IM Hbs) _ _ _ Happ _ Hbs_iom).
      * apply initial_message_is_valid. assumption.
    + subst el. cbn. rewrite equivocator_state_project_zero.
      rewrite Hes_pr_eqv. assumption.
    + apply Hsubsumption; assumption.
Qed.

End generalized_constraints.

(** ** VLSM Equivocators Simulating Free Composite

In this section we show that the composition of equivocators with no-message
equivocation can simulate the free composition of regular nodes.

To allow reusing this result in the proof for simulating fixed equivocation,
we first prove an intermediate result, where both the composite VLSMs are
pre-loaded with the same set of messages.
*)
Section seeded_all_equivocating.

Context {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (Finite_index := Listing_finite_transparent finite_index)
  (FreeE := free_composite_vlsm (equivocator_IM IM))
  (PreFreeE := pre_loaded_with_all_messages_vlsm FreeE)
  (FreeE_Hbs := free_composite_HasBeenSentCapability (equivocator_IM IM) finite_index (equivocator_Hbs IM Hbs))
  (seed : message -> Prop)
  (SeededXE : VLSM message := composite_no_equivocation_vlsm_with_pre_loaded (equivocator_IM IM) (free_constraint _) (equivocator_Hbs IM Hbs) seed)
  (Free := free_composite_vlsm IM)
  (SeededFree := pre_loaded_vlsm Free seed)
  .

Existing Instance Finite_index.

(** Since [replayed_trace_from] was defined for a subset of the equivocators, we
here define a specialized version of it when the set of all equivocators is used.

We then restate some of the lemmas concering [replayed_trace_from] for the new
definition.
*)
Definition all_equivocating_replayed_trace_from
  (full_replay_state : composite_state (equivocator_IM IM))
  (is : composite_state (equivocator_IM IM))
  (tr : list (composite_transition_item (equivocator_IM IM)))
  : list (composite_transition_item (equivocator_IM IM))
  :=
  let Hproj := sub_composition_all_full_projection (equivocator_IM IM) (equivocators_no_equivocations_constraint IM Hbs) in
  replayed_trace_from IM index_listing index_listing
    full_replay_state
    (composite_state_sub_projection (equivocator_IM IM) index_listing is)
    (VLSM_full_projection_finite_trace_project Hproj tr).

Lemma replayed_trace_from_valid_equivocating
  (full_replay_state : composite_state (equivocator_IM IM))
  (Hfull_replay_state : valid_state_prop SeededXE full_replay_state)
  (is : composite_state (equivocator_IM IM))
  (tr : list (composite_transition_item (equivocator_IM IM)))
  (Htr : finite_valid_trace SeededXE is tr)
  : finite_valid_trace_from SeededXE
      full_replay_state (all_equivocating_replayed_trace_from full_replay_state is tr).
Proof.
  apply
    (sub_replayed_trace_from_valid_equivocating IM Hbs _ finite_index seed
      index_listing _ Hfull_replay_state
    ).
  pose (Hproj := preloaded_sub_composition_all_full_projection (equivocator_IM IM) (no_equivocations_additional_constraint_with_pre_loaded (equivocator_IM IM) (free_constraint _) (equivocator_Hbs IM Hbs) seed) seed).
  apply (VLSM_full_projection_finite_valid_trace Hproj) in Htr.
  revert Htr.
  apply VLSM_incl_finite_valid_trace.
  apply basic_VLSM_incl_preloaded_with; intro; intros
  ; [assumption| |assumption..].
  destruct H as [Hv Hc].
  split; [assumption|].
  split; [|exact I].
  destruct om; [| exact I].
  apply proj1 in Hc.
  destruct Hc as [Hc | Hc]; [|right; assumption].
  left.
  destruct Hc as [i Hsent].
  remember (@free_sub_free_index index _ Finite_index i) as sub_i.
  unfold free_sub_free_state in Hsent.
  exists sub_i. subst. assumption.
Qed.

(** Specializing the [generalized_equivocators_finite_valid_trace_init_to_rev]
result using the [free_constraint] for the composition of regular nodes
and the no-message-equivocation constraint for the composition of equivocators.
*)
Lemma seeded_equivocators_finite_valid_trace_init_to_rev
  (no_initial_messages_in_IM : no_initial_messages_in_IM_prop IM)
  isX sX trX
  (HtrX : finite_valid_trace_init_to SeededFree isX sX trX)
  : exists is, equivocators_total_state_project IM is = isX /\
    exists s, equivocators_total_state_project IM s = sX /\
    exists tr, equivocators_total_trace_project IM tr = trX /\
    finite_valid_trace_init_to SeededXE is s tr /\
    finite_trace_last_output trX = finite_trace_last_output tr.
Proof.
  apply
    (generalized_equivocators_finite_valid_trace_init_to_rev
      IM Hbs finite_index)
  ; [..|assumption].
  - intro; intros. split; [|exact I].
    destruct om; [|exact I].
    destruct Hom as [Hsent|Hinitial]; [left;assumption|].
    right.
    destruct Hinitial as [[i [[mi Hmi] Him]]|Hseeded]; [exfalso|assumption].
    elim (no_initial_messages_in_IM i mi).
    assumption.
  - clear isX sX trX HtrX.
    intro; intros.
    destruct iom as [im|].
    2: {
      exists []. exists eqv_state_s.
      split; [constructor; assumption|].
      split; [reflexivity|].
      split; [assumption|].
      exact I.
    }
    specialize (NoEquivocation.seeded_no_equivocation_incl_preloaded (equivocator_IM IM) (free_constraint _) (equivocator_Hbs IM Hbs) seed)
      as HinclE.
    apply valid_trace_forget_last in Hmsg_trace.
    specialize
      (replayed_trace_from_valid_equivocating
       _ Hstate_valid _ _ Hmsg_trace
      )
      as Hmsg_trace_full_replay.
    remember (all_equivocating_replayed_trace_from _ _ _ ) as emsg_tr.
    apply valid_trace_add_default_last in Hmsg_trace_full_replay.
    eexists _,_; split; [exact Hmsg_trace_full_replay|].
    subst.
    unfold all_equivocating_replayed_trace_from.
    rewrite
      (equivocators_total_state_project_replayed_trace_from
        IM index_listing index_listing
        eqv_state_s).
    rewrite
      (equivocators_total_trace_project_replayed_trace_from
        IM index_listing index_listing
        eqv_state_s).
    repeat split. simpl.
    destruct Hfinal_msg as [Hfinal_msg | Hinitial]; [|right; assumption].
    left.
    apply valid_trace_first_pstate in Hmsg_trace_full_replay as Hfst.
    apply valid_state_has_trace in Hfst as [is_s [tr_s [Htr_s His_s]]].
    specialize (finite_valid_trace_from_to_app SeededXE _ _ _ _ _ Htr_s Hmsg_trace_full_replay) as Happ.
    apply (VLSM_incl_finite_valid_trace_from_to HinclE) in Happ.
    apply
      (has_been_sent_examine_one_trace FreeE_Hbs _ _ _ (conj Happ His_s)).

    apply Exists_app. right.
    destruct_list_last eqv_msg_tr eqv_msg_tr' itemX Heqv_msg_tr
    ; [inversion Hfinal_msg|].
    rewrite finite_trace_last_output_is_last in Hfinal_msg.
    apply Exists_app. right.
    unfold VLSM_full_projection_finite_trace_project, pre_VLSM_full_projection_finite_trace_project.
    rewrite! map_app.
    apply Exists_app. right. simpl. left. assumption.
Qed.

End seeded_all_equivocating.

Section all_equivocating.

Context {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (Free := free_composite_vlsm IM)
  (XE : VLSM message := equivocators_no_equivocations_vlsm IM Hbs)
  .

(** Further specializing [seeded_equivocators_finite_valid_trace_init_to_rev]
to remove the pre-loading operation.
*)
Lemma equivocators_finite_valid_trace_init_to_rev
  (no_initial_messages_in_IM : no_initial_messages_in_IM_prop IM)
  isX sX trX
  (HtrX : finite_valid_trace_init_to Free isX sX trX)
  : exists is, equivocators_total_state_project IM is = isX /\
    exists s, equivocators_total_state_project IM s = sX /\
    exists tr, equivocators_total_trace_project IM tr = trX /\
    finite_valid_trace_init_to XE is s tr /\
    finite_trace_last_output trX = finite_trace_last_output tr.
Proof.
  specialize (vlsm_is_pre_loaded_with_False Free) as Heq.
  apply (VLSM_eq_finite_valid_trace_init_to Heq) in HtrX.
  specialize
    (seeded_equivocators_finite_valid_trace_init_to_rev
      IM Hbs finite_index (fun m => False) no_initial_messages_in_IM
      _ _ _ HtrX)
    as [is [His [s [Hs [tr [Htr_pr [Htr Houtput]]]]]]].
  exists is. split; [assumption|].
  exists s. split; [assumption|].
  exists tr. split; [assumption|].
  split; [|assumption].
  unfold composite_no_equivocation_vlsm_with_pre_loaded in Htr.
  remember (no_equivocations_additional_constraint_with_pre_loaded _ _ _ _)
    as constraint.
  clear Heq.
  specialize (vlsm_is_pre_loaded_with_False (composite_vlsm (equivocator_IM IM) constraint))
    as Heq.
  apply (VLSM_eq_finite_valid_trace_init_to Heq) in Htr.
  revert Htr.
  apply VLSM_incl_finite_valid_trace_init_to.
  apply constraint_subsumption_incl.
  apply preloaded_constraint_subsumption_stronger.
  apply strong_constraint_subsumption_strongest.
  subst.
  clear.
  intros l (s, om) Hc.
  split; [|exact I].
  destruct om as [m|]; [|exact I].
  apply proj1 in Hc. assumption.
Qed.

End all_equivocating.
