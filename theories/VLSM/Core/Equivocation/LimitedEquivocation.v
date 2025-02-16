From stdpp Require Import prelude.
From Coq Require Import FinFun Rdefinitions RIneq.
From VLSM Require Import Lib.Preamble Lib.Measurable Lib.StdppListSet.
From VLSM Require Import Core.VLSM Core.VLSMProjections Core.MessageDependencies Core.Composition Core.Equivocation Core.Equivocation.FixedSetEquivocation Core.Equivocation.TraceWiseEquivocation.
From VLSM Require Import Core.Equivocation.WitnessedEquivocation.

(** * VLSM Limited Message Equivocation

In this section we define the notion of limited (message-based) equivocation.

This notion is slightly harder to define than that of fixed-set equivocation,
because, while for the latter we fix a set and let only the nodes belonging to
that set to equivocate, in the case of limited equivocation, the set of nodes
equivocating can change dynamically, each node being virtually allowed to
equivocate as long as the weight of all nodes currently equivocating does
not pass a certain threshold.

As we need to be able to measure the amount of equivocation in a given state
to design a composition constraint preventing equivocation weight from passing
the threshold, we need an appropriate measure of equivocation.
We here choose [is_equivocating_tracewise] as this measure.

Moreover, to further limit the amount of equivocation allowed when producing
a message, we assume a full-node-like  condition to be satisfied by all nodes.
This  guarantees that whenever a message not-previously send is received in a
state, the amount of equivocation would only grow with the weight of the
sender of the message (if that wasn't already known as an equivocator).
*)

Section limited_message_equivocation.
Context
  {message : Type}
  `{EqDecision index}
  `{ReachableThreshold index}
  (IM : index -> VLSM message)
  (Hbs : forall i, HasBeenSentCapability (IM i))
  (Hbr : forall i, HasBeenReceivedCapability (IM i))
  (Hbo := fun i => HasBeenObservedCapability_from_sent_received (IM i))
  (Free := free_composite_vlsm IM)
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (Free_HasBeenSentCapability : HasBeenSentCapability Free := free_composite_HasBeenSentCapability IM finite_index Hbs)
  (Free_HasBeenReceivedCapability : HasBeenReceivedCapability Free := free_composite_HasBeenReceivedCapability IM finite_index Hbr)
  (Free_HasBeenObservedCapability : HasBeenObservedCapability Free := free_composite_HasBeenObservedCapability IM finite_index Hbo)
  (sender : message -> option index)
  {is_equivocating_tracewise_no_has_been_sent_dec : RelDecision (is_equivocating_tracewise_no_has_been_sent IM (fun i => i) sender)}
  (Htracewise_BasicEquivocation : BasicEquivocation (composite_state IM) index
    := equivocation_dec_tracewise IM id sender finite_index)
  (tracewise_not_heavy := @not_heavy _ _ _ _ Htracewise_BasicEquivocation)
  .

Definition limited_equivocation_constraint
  (l : composite_label IM)
  (som : composite_state IM * option message)
  :=
  tracewise_not_heavy (fst (composite_transition IM l som)).


Definition limited_equivocation_vlsm_composition
  :=
  composite_vlsm IM limited_equivocation_constraint.

Lemma full_node_limited_equivocation_valid_state_weight s
  : valid_state_prop limited_equivocation_vlsm_composition s ->
    tracewise_not_heavy s.
Proof.
  intro Hs.
  unfold tracewise_not_heavy, not_heavy.
  induction Hs using valid_state_prop_ind.
  - replace (equivocation_fault s) with 0%R
      by (symmetry;apply initial_state_equivocators_weight;assumption).
    destruct threshold. simpl. apply Rge_le. assumption.
  - destruct Ht as [[Hs [Hom [Hv Hw]]] Ht].
    unfold transition in Ht. simpl in Ht.
    unfold limited_equivocation_constraint in Hw. simpl in Hw.
    rewrite Ht in Hw.
    assumption.
Qed.

End limited_message_equivocation.

Section fixed_limited_message_equivocation.

(** ** Fixed Message Equivocation implies Limited Message Equivocation

In this section we show that if the set of allowed equivocators for a fixed
equivocation constraint is of weight smaller than the threshold accepted for
limited message equivocation, then any valid trace for the fixed equivocation
constraint is also a trace under the limited equivocation constraint.
*)


Context
  {message : Type}
  `{EqDecision index}
  (IM : index -> VLSM message)
  (Hbs : forall i, HasBeenSentCapability (IM i))
  (Hbr : forall i, HasBeenReceivedCapability (IM i))
  (Hbo := fun i => HasBeenObservedCapability_from_sent_received (IM i))
  (equivocators : list index)
  (Free := free_composite_vlsm IM)
  (Fixed := fixed_equivocation_vlsm_composition IM Hbs Hbr equivocators)
  (StrongFixed := strong_fixed_equivocation_vlsm_composition IM Hbs equivocators)
  (PreFree := pre_loaded_with_all_messages_vlsm Free)
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (Free_hbo := free_composite_HasBeenObservedCapability IM finite_index Hbo)
  (Free_hbr := free_composite_HasBeenReceivedCapability IM finite_index Hbr)
  (Free_hbs := free_composite_HasBeenSentCapability IM finite_index Hbs)
  `{ReachableThreshold index}
  (Hlimited : (sum_weights (remove_dups equivocators) <= proj1_sig threshold)%R )
  (sender : message -> option index)
  (Hsender_safety : sender_safety_alt_prop IM (fun i => i) sender)
  {is_equivocating_tracewise_no_has_been_sent_dec : RelDecision (is_equivocating_tracewise_no_has_been_sent IM (fun i => i) sender)}
  (Limited : VLSM message := limited_equivocation_vlsm_composition IM finite_index sender)
  (Htracewise_BasicEquivocation : BasicEquivocation (composite_state IM) index
    := equivocation_dec_tracewise IM (fun i => i) sender finite_index)
  (tracewise_not_heavy := @not_heavy _ _ _ _ Htracewise_BasicEquivocation)
  (tracewise_equivocating_validators := @equivocating_validators _ _ _ _ Htracewise_BasicEquivocation)
  .

Lemma StrongFixed_valid_state_not_heavy s
  (Hs : valid_state_prop StrongFixed s)
  : tracewise_not_heavy s.
Proof.
  cut (tracewise_equivocating_validators s ⊆ equivocators).
  { intro Hincl.
    unfold tracewise_not_heavy, not_heavy.
    transitivity (sum_weights (remove_dups equivocators)); [|assumption].
    apply sum_weights_subseteq
    ; [apply equivocating_validators_nodup|apply NoDup_remove_dups|].
    intros i Hi.
    apply elem_of_remove_dups, Hincl. assumption.
  }
  assert (StrongFixedinclPreFree : VLSM_incl StrongFixed PreFree).
  { apply VLSM_incl_trans with (machine Free).
    - apply (constraint_free_incl IM (strong_fixed_equivocation_constraint IM Hbs equivocators)).
    - apply vlsm_incl_pre_loaded_with_all_messages_vlsm.
  }
  apply valid_state_has_trace in Hs as [is [tr Htr]].
  apply (VLSM_incl_finite_valid_trace_init_to StrongFixedinclPreFree) in Htr as Hpre_tr.
  intros v Hv.
  apply equivocating_validators_is_equivocating_tracewise_iff in Hv as Hvs'.
  specialize (Hvs' _ _ Hpre_tr).
  destruct Hvs' as [m0 [Hsender0 [pre [item [suf [Heqtr [Hm0 Heqv]]]]]]].
  rewrite Heqtr in Htr.
  destruct Htr as [Htr Hinit].
  change (pre ++ item::suf) with (pre ++ [item] ++ suf) in Htr.
  apply (finite_valid_trace_from_to_app_split StrongFixed) in Htr.
  destruct Htr as [Hpre Hitem].
  apply (VLSM_incl_finite_valid_trace_from_to StrongFixedinclPreFree) in Hpre as Hpre_pre.
  apply valid_trace_last_pstate in Hpre_pre as Hs_pre.
  apply (finite_valid_trace_from_to_app_split StrongFixed), proj1 in Hitem.
  inversion Hitem; subst; clear Htl Hitem. simpl in Hm0. subst.
  destruct Ht as [[_ [_ [_ Hc]]] _].
  destruct Hc as [[i [Hi Hsenti]] | Hemit].
  + assert (Hsent : composite_has_been_sent IM Hbs (finite_trace_last is pre) m0)
      by (exists i; assumption).
    apply (composite_proper_sent IM finite_index) in Hsent; [|assumption].
    specialize (Hsent _ _ (conj Hpre_pre Hinit)).
    contradiction.
  +  apply (SubProjectionTraces.sub_can_emit_sender IM equivocators (fun i => i) sender Hsender_safety)
        with (v0 := v) in Hemit
      ; assumption.
Qed.

Lemma StrongFixed_incl_Limited : VLSM_incl StrongFixed Limited.
Proof.
  apply constraint_subsumption_incl.
  intros (i, li) (s, om) Hpv.
  unfold limited_equivocation_constraint.
  destruct (composite_transition _ _ _) as (s', om') eqn:Ht.
  specialize (input_valid_transition_destination StrongFixed (conj Hpv Ht)) as Hs'.
  apply StrongFixed_valid_state_not_heavy in Hs'.
  assumption.
Qed.

Lemma Fixed_incl_Limited : VLSM_incl Fixed Limited.
Proof.
  specialize (Fixed_eq_StrongFixed IM Hbs Hbr finite_index equivocators)
    as Heq.
  apply VLSM_eq_proj1 in Heq.
  apply VLSM_incl_trans with (machine StrongFixed).
  - apply Heq.
  - apply StrongFixed_incl_Limited.
Qed.

End fixed_limited_message_equivocation.

Section has_limited_equivocation.

(** ** Limited Equivocation derived from Fixed Equivocation

We say that a trace has the [fixed_limited_equivocation_prop]erty if it is
valid for the composition using a [generalized_fixed_equivocation_constraint]
induced by a subset of indices whose weight is less than the allowed
[ReachableThreshold].
*)

Context
  {message : Type}
  {index : Type}
  `{EqDecision index}
  (IM : index -> VLSM message)
  (Hbs : forall i, HasBeenSentCapability (IM i))
  (Hbr : forall i, HasBeenReceivedCapability (IM i))
  `{ReachableThreshold index}
  .

Definition fixed_limited_equivocation_prop
  (s : composite_state IM)
  (tr : list (composite_transition_item IM))
  : Prop
  := exists (equivocators : list index) (Fixed := fixed_equivocation_vlsm_composition IM Hbs Hbr equivocators),
    (sum_weights (remove_dups equivocators) <= `threshold)%R /\
    finite_valid_trace Fixed s tr.

Context
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (sender : message -> option index)
  (message_dependencies : message -> set message)
  {is_equivocating_tracewise_no_has_been_sent_dec : RelDecision (is_equivocating_tracewise_no_has_been_sent IM (fun i => i) sender)}
  (Limited : VLSM message := limited_equivocation_vlsm_composition IM finite_index sender)
  .

(** Traces with the [fixed_limited_equivocation_prop]erty are valid for the
composition using a [limited_equivocation_constraint].
*)
Lemma traces_exhibiting_limited_equivocation_are_valid
  (Hsender_safety : sender_safety_alt_prop IM (fun i => i) sender)
  : forall s tr, fixed_limited_equivocation_prop s tr -> finite_valid_trace Limited s tr.
Proof.
  intros s tr [equivocators [Hlimited Htr]].
  eapply VLSM_incl_finite_valid_trace; [| eassumption].
  apply Fixed_incl_Limited; assumption.
Qed.

(** Traces having the [strong_trace_witnessing_equivocation_prop]erty, which
are valid for the free composition and whose final state is [not_heavy] have
the [fixed_limited_equivocation_prop]erty.
*)
Lemma traces_exhibiting_limited_equivocation_are_valid_rev
  (Hke : WitnessedEquivocationCapability IM id sender finite_index)
  (Hbo := fun i => HasBeenObservedCapability_from_sent_received (IM i))
  (HMsgDep : forall i, MessageDependencies message_dependencies (IM i))
  (Hfull : forall i, message_dependencies_full_node_condition_prop message_dependencies (IM i))
  (no_initial_messages_in_IM : no_initial_messages_in_IM_prop IM)
  (can_emit_signed : channel_authentication_prop IM id sender)
  (Htracewise_basic_equivocation : BasicEquivocation (composite_state IM) index
    := equivocation_dec_tracewise IM (fun i => i) sender finite_index)
  (tracewise_not_heavy := @not_heavy _ _ _ _ Htracewise_basic_equivocation)
  : forall is s tr, strong_trace_witnessing_equivocation_prop IM id sender finite_index is tr ->
    finite_valid_trace_init_to (free_composite_vlsm IM) is s tr ->
    tracewise_not_heavy s ->
    fixed_limited_equivocation_prop is tr.
Proof.
  intros is s tr Hstrong Htr Hnot_heavy.
  exists (equivocating_validators s).
  split; cycle 1.
  - eapply valid_trace_forget_last, strong_witness_has_fixed_equivocation; eassumption.
  - replace (sum_weights _) with (equivocation_fault s); [assumption|].
    apply set_eq_nodup_sum_weight_eq.
    + apply equivocating_validators_nodup.
    + apply NoDup_remove_dups.
    + apply ListSetExtras.set_eq_extract_forall.
      intro i. rewrite elem_of_remove_dups. intuition.
Qed.

(** Traces with the [strong_trace_witnessing_equivocation_prop]erty, which are
valid for the composition using a [limited_equivocation_constraint]
have the [fixed_limited_equivocation_prop]erty.
*)
Lemma limited_traces_exhibiting_limited_equivocation_are_valid_rev
  (Hke : WitnessedEquivocationCapability IM id sender finite_index)
  (Hbo := fun i => HasBeenObservedCapability_from_sent_received (IM i))
  (HMsgDep : forall i, MessageDependencies message_dependencies (IM i))
  (Hfull : forall i, message_dependencies_full_node_condition_prop message_dependencies (IM i))
  (no_initial_messages_in_IM : no_initial_messages_in_IM_prop IM)
  (can_emit_signed : channel_authentication_prop IM id sender)
  : forall s tr, strong_trace_witnessing_equivocation_prop IM id sender finite_index s tr ->
    finite_valid_trace Limited s tr -> fixed_limited_equivocation_prop s tr.
Proof.
  intros s tr Hstrong Htr.
  apply proj1 in Htr as Hnot_heavy.
  apply finite_valid_trace_last_pstate, full_node_limited_equivocation_valid_state_weight in Hnot_heavy.
  assert (Hfree_tr : finite_valid_trace (free_composite_vlsm IM) s tr). {
    revert Htr. apply VLSM_incl_finite_valid_trace.
    apply constraint_free_incl.
  }
  clear Htr.
  apply valid_trace_add_default_last in Hfree_tr.
  apply traces_exhibiting_limited_equivocation_are_valid_rev with (finite_trace_last s tr); assumption.
Qed.

(** Any state which is valid for limited equivocation can be produced by
a trace having the [fixed_limited_equivocation_prop]erty.
*)
Lemma limited_valid_state_has_trace_exhibiting_limited_equivocation
  (Hke : WitnessedEquivocationCapability IM id sender finite_index)
  (Hbo := fun i => HasBeenObservedCapability_from_sent_received (IM i))
  (HMsgDep : forall i, MessageDependencies message_dependencies (IM i))
  (Hfull : forall i, message_dependencies_full_node_condition_prop message_dependencies (IM i))
  (no_initial_messages_in_IM : no_initial_messages_in_IM_prop IM)
  (can_emit_signed : channel_authentication_prop IM id sender)
  : forall s, valid_state_prop Limited s ->
    exists is tr, finite_trace_last is tr = s /\ fixed_limited_equivocation_prop is tr.
Proof.
  intros s Hs.
  assert (Hfree_s : valid_state_prop (free_composite_vlsm IM) s). {
    revert Hs.
    apply VLSM_incl_valid_state.
    apply constraint_free_incl.
   }
  destruct
    (free_has_strong_trace_witnessing_equivocation_prop IM finite_index Hbs Hbr id sender finite_index _ s Hfree_s)
    as [is [tr [Htr Heqv]]].
  exists is, tr.
  apply valid_trace_get_last in Htr as Hlst.
  split; [assumption|].
  apply full_node_limited_equivocation_valid_state_weight in Hs.
  apply traces_exhibiting_limited_equivocation_are_valid_rev with s.
  all: assumption.
Qed.

End has_limited_equivocation.
