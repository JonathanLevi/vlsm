From stdpp Require Import prelude finite.
From Coq Require Import FunctionalExtensionality Lia FinFun Eqdep Program.
From VLSM Require Import Lib.Preamble Lib.ListExtras Lib.StdppListSet.
From VLSM Require Import Core.VLSM Core.VLSMProjections Core.ProjectionTraces Core.Composition Core.Equivocation Core.EquivocationProjections Core.Equivocation.NoEquivocation.

(** * VLSM Subcomposition *)

Section sub_composition.

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (sub_index_list : list index)
  .

Definition sub_index_prop (i : index) : Prop := i ∈ sub_index_list.

Local Program Instance sub_index_prop_dec
  (i : index)
  : Decision (sub_index_prop i).
Next Obligation.
  unfold sub_index_prop.
  apply decide_rel; typeclasses eauto.
Qed.

Definition sub_index : Type
  := dec_sig sub_index_prop.

Definition sub_IM
  (ei : sub_index)
  : VLSM message
  := IM (proj1_sig ei).

Lemma sub_IM_state_pi
  (i : index)
  (s : composite_state sub_IM)
  (e1 e2 : sub_index_prop i)
  : s (dexist i e1) = s (dexist i e2).
Proof.
  unfold composite_state in s. simpl in s. unfold _composite_state in s.
  apply (dsig_f_equal (fun i => vstate (IM i)) s).
Qed.

Lemma sub_IM_state_update_eq
  (i : index)
  (s : composite_state sub_IM)
  (si : vstate (IM i))
  (e1 e2 : sub_index_prop i)
  : state_update sub_IM s (dec_exist _ i e1) si (dec_exist _ i e2) = si.
Proof.
  cut (forall be1 be2, be1 = be2 ->
      state_update sub_IM s (exist _ i be1) si (exist _ i be2) = si).
  { intro Heq. apply Heq. apply proof_irrel. }
  intros. subst. apply state_update_eq.
Qed.


Definition free_sub_vlsm_composition : VLSM message
  := free_composite_vlsm sub_IM.

Definition seeded_free_sub_composition
  (messageSet : message -> Prop)
  := pre_loaded_vlsm free_sub_vlsm_composition
      (fun m => messageSet m \/ composite_initial_message_prop IM m).

Definition composite_state_sub_projection
  (s : composite_state IM)
  : composite_state sub_IM
  := fun (subi : sub_index) => s (proj1_sig subi) : vstate (sub_IM subi).

Lemma composite_initial_state_sub_projection
  (s : composite_state IM)
  (Hs : composite_initial_state_prop IM s)
  : composite_initial_state_prop sub_IM (composite_state_sub_projection s).
Proof.
  intros (i, Hi). apply Hs.
Qed.

Definition composite_label_sub_projection
  (l : composite_label IM)
  (i := projT1 l)
  (e : sub_index_prop i)
  : composite_label sub_IM
  :=
  existT (dec_exist _ i e) (projT2 l).

Definition lift_sub_label
  (l : composite_label sub_IM)
  : composite_label IM
  :=
  existT (proj1_sig (projT1 l)) (projT2 l).

Definition lift_sub_state_to
  (s0 : composite_state IM)
  (s : composite_state sub_IM)
  : composite_state IM
  := fun i =>
    match @decide  (sub_index_prop i) (sub_index_prop_dec i) with
    | left e =>  s (dec_exist _ i e)
    | _ => s0 i
    end.

Definition lift_sub_state := lift_sub_state_to (fun (n : index) => proj1_sig (vs0 (IM n))).

Lemma lift_sub_state_to_eq
  (s0 : composite_state IM)
  (s : composite_state sub_IM)
  i
  (Hi : sub_index_prop i)
  : lift_sub_state_to s0 s i = s (dec_exist _ i Hi).
Proof.
  unfold lift_sub_state_to.
  case_decide; [|contradiction].
  apply sub_IM_state_pi.
Qed.

Lemma lift_sub_state_to_neq
  (s0 : composite_state IM)
  (s : composite_state sub_IM)
  i
  (Hni : ~sub_index_prop i)
  : lift_sub_state_to s0 s i = s0 i.
Proof.
  unfold lift_sub_state_to.
  case_decide; [contradiction|].
  reflexivity.
Qed.

Lemma composite_state_sub_projection_lift_to
  (s0 : composite_state IM)
  (s : composite_state sub_IM)
  : composite_state_sub_projection (lift_sub_state_to s0 s) = s.
Proof.
  extensionality sub_i.
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst.
  unfold composite_state_sub_projection.
  simpl.
  rewrite lift_sub_state_to_eq with (Hi := Hi).
  reflexivity.
Qed.

Lemma lift_sub_state_to_neq_state_update
  (s0 : composite_state IM)
  (s : composite_state sub_IM)
  i
  (Hni : ~sub_index_prop i)
  si'
  : state_update IM (lift_sub_state_to s0 s) i si' =
    lift_sub_state_to (state_update IM s0 i si') s.
Proof.
  symmetry.
  apply functional_extensionality_dep. intro j.
  destruct (decide (j = i)).
  - subst. rewrite state_update_eq.
    unfold lift_sub_state_to. case_decide; [contradiction|].
    apply state_update_eq.
  - rewrite state_update_neq by congruence.
    unfold lift_sub_state_to.
    case_decide; [reflexivity|].
    apply state_update_neq. congruence.
Qed.

Section sec_induced_sub_projection.

Context
  (constraint : composite_label IM -> composite_state IM * option message -> Prop)
  (X := composite_vlsm IM constraint)
  .

Definition composite_label_sub_projection_option
  (l : composite_label IM)
  : option (composite_label sub_IM) :=
  match decide (projT1 l ∈ sub_index_list) with
  | left i_in => Some (composite_label_sub_projection l i_in)
  | _ => None
  end.

(** By restricting the components of a composition to a subset we obtain a
[projection_induced_vlsm].
*)
Definition induced_sub_projection : VLSM message :=
  projection_induced_vlsm X (composite_type sub_IM)
    composite_label_sub_projection_option
    composite_state_sub_projection
    lift_sub_label lift_sub_state.

Lemma induced_sub_projection_transition_consistency_None
  : weak_projection_transition_consistency_None X (composite_type sub_IM)
      composite_label_sub_projection_option composite_state_sub_projection.
Proof.
  intros lX HlX sX om s'X om' HtX.
  extensionality sub_i.
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst sub_i.
  unfold composite_state_sub_projection. simpl.
  destruct lX as [x v].
  apply proj2 in HtX. cbn in HtX.
  destruct (vtransition _ _ _) as (si', _om').
  inversion_clear HtX.
  rewrite state_update_neq; [reflexivity|].
  intros ->.
  unfold composite_label_sub_projection_option in HlX.
  simpl in HlX.
  case_decide; [discriminate|contradiction].
Qed.

Lemma composite_label_sub_projection_option_lift
  : induced_projection_label_lift_prop (free_composite_vlsm IM) (composite_type sub_IM)
      composite_label_sub_projection_option lift_sub_label.
Proof.
  intros (sub_i, li).
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst.
  unfold lift_sub_label, composite_label_sub_projection_option.
  simpl.
  case_decide; [|contradiction].
  unfold composite_label_sub_projection.
  f_equal. simpl.
  apply
    (@dec_sig_sigT_eq _ _ sub_index_prop_dec (fun i => vlabel (IM i))).
  reflexivity.
Qed.

Lemma composite_state_sub_projection_lift
  : induced_projection_state_lift_prop (free_composite_vlsm IM) (composite_type sub_IM)
      composite_state_sub_projection lift_sub_state.
Proof.
  intro.
  apply composite_state_sub_projection_lift_to.
Qed.

Lemma composite_trace_sub_projection_lift
  (tr : list (composite_transition_item sub_IM))
  : @pre_VLSM_projection_trace_project _ (composite_type IM) _
    composite_label_sub_projection_option composite_state_sub_projection
    (pre_VLSM_full_projection_finite_trace_project _ _ lift_sub_label lift_sub_state tr)
    = tr.
Proof.
  apply (induced_projection_trace_lift (free_composite_vlsm IM)).
  - apply composite_label_sub_projection_option_lift.
  - apply composite_state_sub_projection_lift.
Qed.

Lemma induced_sub_projection_transition_consistency_Some
  : induced_projection_transition_consistency_Some X (composite_type sub_IM)
      composite_label_sub_projection_option composite_state_sub_projection.
Proof.
  intros lX1 lX2 lY HlX1_pr HlX2_pr sX1 sX2 HsXeq_pr iom sX1' oom1 Ht1 sX2' oom2 Ht2.
  destruct lX1 as (i, lXi).
  unfold composite_label_sub_projection_option in HlX1_pr.
  simpl in HlX1_pr. case_decide as Hi; [|discriminate].
  apply Some_inj in HlX1_pr. subst lY.
  destruct lX2 as (_i, _lXi).
  unfold composite_label_sub_projection_option in HlX2_pr.
  simpl in HlX2_pr. case_decide as H_i; [|discriminate].
  apply Some_inj in HlX2_pr.
  unfold composite_label_sub_projection in HlX2_pr.
  simpl in HlX2_pr.
  inversion HlX2_pr.
  subst _i.
  apply
    (@dec_sig_sigT_eq_rev _ _ _ sub_index_prop_dec (fun i => vlabel (IM i)))
    in HlX2_pr as ->.
  apply f_equal_dep with (x := dexist i Hi) in HsXeq_pr as HsXeq_pri.
  cbv in HsXeq_pri.
  cbn in Ht1, Ht2.
  rewrite <- HsXeq_pri in Ht2.
  destruct (vtransition _ _ _) as (si', om').
  inversion Ht1. subst. clear Ht1.
  inversion Ht2. subst. clear Ht2.
  split; [|reflexivity].
  extensionality sub_j.
  apply f_equal_dep with (x := sub_j) in HsXeq_pr.
  destruct_dec_sig sub_j j Hj Heqsub_j.
  subst.
  unfold composite_state_sub_projection in HsXeq_pr |- *.
  simpl in HsXeq_pr |- *.
  destruct (decide (i = j)).
  - subst. rewrite !state_update_eq. reflexivity.
  - rewrite !state_update_neq by congruence. assumption.
Qed.

Lemma weak_induced_sub_projection_transition_consistency_Some
  : weak_projection_transition_consistency_Some X (composite_type sub_IM)
      composite_label_sub_projection_option composite_state_sub_projection
      lift_sub_label lift_sub_state.
Proof.
  apply basic_weak_projection_transition_consistency_Some.
  - apply composite_label_sub_projection_option_lift.
  - apply composite_state_sub_projection_lift.
  - apply induced_sub_projection_transition_consistency_Some.
Qed.

(** The [induced_sub_projection] is actually a [VLSM_projection] of the
original composition.
*)
Lemma induced_sub_projection_is_projection
  : VLSM_projection X induced_sub_projection
    composite_label_sub_projection_option
    composite_state_sub_projection.
Proof.
  apply projection_induced_vlsm_is_projection.
  - apply induced_sub_projection_transition_consistency_None.
  - apply weak_induced_sub_projection_transition_consistency_Some.
Qed.

Lemma induced_sub_projection_valid_projection l s om
  (Hv : vvalid induced_sub_projection l (s, om))
  : exists i, i ∈ sub_index_list /\
    exists l s, input_valid (pre_loaded_with_all_messages_vlsm (IM i)) l (s, om).
Proof.
  destruct l as (sub_i, li).
  destruct Hv as [lX [sX [HlX [Heqs [HsX [Hom Hv]]]]]].
  destruct lX as [i _li].
  unfold composite_label_sub_projection_option in HlX.
  simpl in HlX.
  case_decide; [|congruence].
  unfold composite_label_sub_projection in HlX.
  simpl in HlX.
  apply Some_inj in HlX.
  inversion HlX. subst.
  simpl_existT. subst.
  exists i.
  split; [assumption|].
  apply proj1 in Hv.
  cbn in Hv.
  exists li, (sX i).
  repeat split; [|apply any_message_is_valid_in_preloaded|assumption].
  apply (VLSM_projection_valid_state (preloaded_component_projection IM i)).
  apply (VLSM_incl_valid_state (vlsm_incl_pre_loaded_with_all_messages_vlsm (free_composite_vlsm IM))).
  apply (VLSM_incl_valid_state (constraint_free_incl IM constraint)).
  assumption.
Qed.

End sec_induced_sub_projection.

Section induced_sub_projection_subsumption.

Context
  (constraint1 : composite_label IM -> composite_state IM * option message -> Prop)
  (constraint2 : composite_label IM -> composite_state IM * option message -> Prop)
  .

Lemma induced_sub_projection_constraint_subsumption_incl
  (Hsubsumption : input_valid_constraint_subsumption IM constraint1 constraint2)
  : VLSM_incl (induced_sub_projection constraint1) (induced_sub_projection constraint2).
Proof.
  apply projection_induced_vlsm_incl.
  - apply weak_induced_sub_projection_transition_consistency_Some.
  - apply weak_induced_sub_projection_transition_consistency_Some.
  - apply constraint_subsumption_incl.
    assumption.
Qed.

End induced_sub_projection_subsumption.

Definition from_sub_projection : composite_transition_item IM -> Prop :=
  @pre_VLSM_projection_in_projection _ (composite_type IM) _ composite_label_sub_projection_option.

Definition finite_trace_sub_projection
  : list (composite_transition_item IM) -> list (composite_transition_item sub_IM) :=
  @pre_VLSM_projection_trace_project _ (composite_type IM) _ composite_label_sub_projection_option composite_state_sub_projection.

Section sub_projection_with_no_equivocation_constraints.

Definition sub_has_been_sent_capabilities
  (has_been_sent_capabilities : forall i : index, (HasBeenSentCapability (IM i)))
  : forall i : sub_index, (HasBeenSentCapability (sub_IM i))
  := fun sub_i => has_been_sent_capabilities (proj1_sig sub_i).

Definition sub_has_been_received_capabilities
  (has_been_received_capabilities : forall i : index, (HasBeenReceivedCapability (IM i)))
  : forall i : sub_index, (HasBeenReceivedCapability (sub_IM i))
  := fun sub_i => has_been_received_capabilities (proj1_sig sub_i).

Existing Instance  IndEqDec.

Context
  (constraint : composite_label IM -> composite_state IM * option message -> Prop)
  (has_been_sent_capabilities : forall i : index, (HasBeenSentCapability (IM i)))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (Free := free_composite_vlsm IM)
  (Sub_Free := free_composite_vlsm sub_IM)
  (X := composite_vlsm IM constraint)
  (Pre := pre_loaded_with_all_messages_vlsm (free_composite_vlsm IM))
  .

Fixpoint select_sub_indices
  (l : list index)
  : list sub_index
  :=
  match l with
  | [] => []
  | h :: t =>
    let t' := select_sub_indices t in
    match decide (sub_index_prop h) with
    | left e => dec_exist _ h e :: t'
    | _ => t'
    end
  end.

Definition sub_index_listing : list sub_index := select_sub_indices index_listing.

Lemma in_select_sub_indices
  (a: index)
  (s: sub_index_prop a)
  (l: list index)
  : (dec_exist sub_index_prop a s) ∈ (select_sub_indices l) <-> a ∈ l.
Proof.
  induction l; [simpl; intuition; inversion H|].
  simpl.
  destruct (decide (sub_index_prop a0)); [|rewrite IHl].
  - rewrite 2!elem_of_cons.
    split; intros [Heq | H].
    * left; apply dec_sig_eq_iff in Heq; assumption.
    * right; apply IHl; assumption.
    * left; apply dec_sig_eq_iff; assumption.
    * right; apply IHl; assumption.
  - rewrite !elem_of_cons.
    split; [intuition|].
    intros [Heq | H]; [|assumption].
    subst. contradiction.
Qed.

Lemma select_sub_indices_nodup l (Hl : NoDup l) : NoDup (select_sub_indices l).
Proof.
  induction l; [constructor|].
  inversion Hl. subst.
  simpl. spec IHl H2.
  destruct (decide (sub_index_prop a)); [|assumption].
  constructor; [|assumption].
  intro contra. contradict H1.
  apply in_select_sub_indices in contra.
  assumption.
Qed.

Lemma finite_sub_index : Listing sub_index_listing.
Proof.
  unfold sub_index_listing.
  clear -finite_index.
  destruct finite_index as [Hnodup Hfinite].
  split.
  - apply NoDup_ListNoDup in Hnodup.
    apply NoDup_ListNoDup.
    revert Hnodup.
    apply select_sub_indices_nodup.
  - intros subi. destruct_dec_sig subi i Hi Heq.
    subst.
    apply elem_of_list_In.
    apply in_select_sub_indices.
    apply elem_of_list_In.
    apply Hfinite.
Qed.

Global Instance stdpp_finite_sub_index
  {Hfinite : finite.Finite index}
  : finite.Finite sub_index.
Proof.
  exists (select_sub_indices (enum index)).
  - apply select_sub_indices_nodup. apply Hfinite.
  - intro sub_x. destruct_dec_sig sub_x x Hx Heqsub_x.
    subst.
    apply in_select_sub_indices.
    apply Hfinite.
Qed.

Local Instance Sub_Free_HasBeenSentCapability
  : HasBeenSentCapability Sub_Free
  :=
  free_composite_HasBeenSentCapability sub_IM finite_sub_index (sub_has_been_sent_capabilities has_been_sent_capabilities).

Definition finite_trace_sub_projection_app
  (tr1 tr2 : list (composite_transition_item IM))
  : finite_trace_sub_projection (tr1 ++ tr2) =
    finite_trace_sub_projection tr1 ++ finite_trace_sub_projection tr2
  :=
  @pre_VLSM_projection_trace_project_app _ (composite_type IM) _ composite_label_sub_projection_option composite_state_sub_projection tr1 tr2.

Lemma X_incl_Pre : VLSM_incl X Pre.
Proof.
  apply VLSM_incl_trans with (machine (free_composite_vlsm IM)).
  - apply (constraint_free_incl IM constraint).
  - apply vlsm_incl_pre_loaded_with_all_messages_vlsm.
Qed.

Lemma finite_trace_sub_projection_last_state
  (start : composite_state IM)
  (transitions : list (composite_transition_item IM))
  (Htr : finite_valid_trace_from X start transitions)
  (lstx := finite_trace_last start transitions)
  (lstj := finite_trace_last
    (composite_state_sub_projection start)
    (finite_trace_sub_projection transitions))
  : lstj = composite_state_sub_projection lstx.
Proof.
  apply (VLSM_projection_finite_trace_last (induced_sub_projection_is_projection constraint))
    in Htr.
  symmetry. assumption.
Qed.

Lemma transition_sub_projection
  l s om s' om'
  (Ht : composite_transition IM l  (s, om) = (s', om'))
  (Hsub : sub_index_prop (projT1 l))
  : composite_transition sub_IM
    (existT
      (dec_exist _ (projT1 l) Hsub)
      (projT2 l)
    )
    (composite_state_sub_projection s, om)
    = (composite_state_sub_projection s', om').
Proof.
  simpl. simpl in Ht.
  destruct l as (i, li).
  unfold vtransition. simpl.
  unfold composite_state_sub_projection at 1. simpl.
  destruct (vtransition (IM i) li (s i, om)) as (si', omi') eqn:Hti.
  inversion Ht. subst omi' s'. clear Ht.
  match goal with
  |- (let (_, _) := ?t in _) = _ =>
    replace t with (si', om')
  end.
  f_equal.
  extensionality sub_j.
  destruct_dec_sig sub_j j Hj Heqj.
  subst sub_j. unfold composite_state_sub_projection at 2.
  destruct (decide (j = i)).
  - subst.
    simpl. rewrite state_update_eq.
    apply sub_IM_state_update_eq.
  - rewrite! state_update_neq; [reflexivity|assumption|].
    intro contra. apply dec_sig_eq_iff in contra. contradiction.
Qed.

Lemma valid_sub_projection
  l s om
  (Hv : composite_valid IM l  (s, om))
  (Hsub : sub_index_prop (projT1 l))
  : composite_valid sub_IM
    (existT
      (dec_exist _ (projT1 l) Hsub)
      (projT2 l)
    )
    (composite_state_sub_projection s, om).
Proof.
  simpl. simpl in Hv.
  destruct l as (i, li).
  assumption.
Qed.

Context
  (seed : message -> Prop)
  (sub_constraint : composite_label sub_IM -> composite_state sub_IM * option message -> Prop)
  (Xj := composite_no_equivocation_vlsm_with_pre_loaded sub_IM (free_constraint sub_IM) (sub_has_been_sent_capabilities has_been_sent_capabilities) seed )
  .

Lemma Xj_incl_Pre_Sub_Free
  : VLSM_incl Xj (pre_loaded_with_all_messages_vlsm Sub_Free).
Proof.
  subst Xj.
  unfold composite_no_equivocation_vlsm_with_pre_loaded.
  specialize
    (preloaded_constraint_subsumption_incl sub_IM
      (no_equivocations_additional_constraint_with_pre_loaded sub_IM
        (free_constraint sub_IM) (sub_has_been_sent_capabilities has_been_sent_capabilities)
        seed)
      (free_constraint sub_IM)
    ) as Hincl.
  spec Hincl; [intro; intros; exact I|].
  match goal with
  |- context [pre_loaded_vlsm ?v _] =>
    apply VLSM_incl_trans with (machine (pre_loaded_with_all_messages_vlsm v))
  end; [| apply Hincl].
  clear Hincl.
  match goal with
  |- context [pre_loaded_with_all_messages_vlsm ?v] =>
    apply VLSM_incl_trans with (machine (pre_loaded_vlsm v (fun m => True)))
  end.
  - match goal with
    |- context [pre_loaded_vlsm ?v _] =>
      apply (pre_loaded_vlsm_incl v seed (fun m => True))
    end.
    intuition.
  - match goal with
    |- context [pre_loaded_with_all_messages_vlsm ?v] =>
      specialize (pre_loaded_with_all_messages_vlsm_is_pre_loaded_with_True v) as Hincl
    end.
    apply VLSM_eq_incl_iff in Hincl.
    apply proj2 in Hincl.
    assumption.
Qed.

(**
Property of a composite trace requiring that every message received in an
transition involving a machine in the chosen subset must either belong to
the set specified by [seed], or it must [have_been_sent] by some machine
in the chosen subset (prior to it being received).
*)
Definition trace_sub_item_input_is_seeded_or_sub_previously_sent
  (tr : list (composite_transition_item IM))
  : Prop
  :=
  forall pre item suf m,
    tr = pre ++ [item] ++ suf ->
    input item = Some m ->
    from_sub_projection item ->
    seed m \/ exists pre_item, pre_item ∈ pre /\ output pre_item = Some m /\ from_sub_projection pre_item.

Definition state_sub_item_input_is_seeded_or_sub_previously_sent
  (s : composite_state IM)
  : Prop
  := forall is tr,
    finite_valid_trace_init_to Pre is s tr ->
    trace_sub_item_input_is_seeded_or_sub_previously_sent tr.

Lemma finite_valid_trace_sub_projection
  (s : composite_state IM)
  (tr : list (composite_transition_item IM))
  (Hmsg :  trace_sub_item_input_is_seeded_or_sub_previously_sent tr)
  (Htr : finite_valid_trace X s tr)
  : finite_valid_trace Xj (composite_state_sub_projection s) (finite_trace_sub_projection tr).
Proof.
  destruct Htr as [Htr His].
  apply (composite_initial_state_sub_projection s) in His.
  split; [|assumption].
  apply (initial_state_is_valid Xj) in His as Hisp.
  induction tr using rev_ind; simpl
  ; [constructor; assumption|].
  apply finite_valid_trace_from_app_iff in Htr.
  destruct Htr as [Htr Hx].
  spec IHtr.
  { intros pre item suf m Heq Hin_m Hitem.
    subst tr.
    specialize (Hmsg pre item (suf ++ [x]) m).
    rewrite! app_assoc in Hmsg.
    specialize (Hmsg eq_refl Hin_m Hitem).
    destruct Hmsg as [Hseed | Hmsg]
    ; [left | right] ; assumption.
  }
  spec IHtr Htr.
  rewrite finite_trace_sub_projection_app.
  apply finite_valid_trace_from_app_iff.
  split; [assumption|].
  match goal with
  |- finite_valid_trace_from _ ?l _ => remember l as lst
  end.
  assert (Hlst : valid_state_prop Xj lst).
  { apply finite_valid_trace_last_pstate in IHtr. subst. assumption. }
  simpl.
  unfold pre_VLSM_projection_transition_item_project, composite_label_sub_projection_option.
  case_decide; [|constructor; assumption].
  apply (finite_valid_trace_singleton Xj).
  inversion Hx; subst. simpl in *.
  destruct Ht as [Hv Ht].
  specialize (transition_sub_projection _ _ _ _ _ Ht H)
    as Htj.
  destruct Hv as [_ [_ [Hv Hc]]].
  specialize (valid_sub_projection _ _ _ Hv H)
    as Hvj.
  rewrite <- (finite_trace_sub_projection_last_state s tr Htr) in Htj, Hvj.
  repeat split; [assumption | | assumption | | assumption].
  - destruct iom as [m|]; [|apply (option_valid_message_None Xj)].
    apply (option_valid_message_Some Xj).
    clear -Hmsg m H IHtr tr.
    remember {| input := Some m |} as x.
    specialize (Hmsg tr x []).
    assert (Hx : from_sub_projection x).
    { unfold from_sub_projection at 1, pre_VLSM_projection_in_projection, composite_label_sub_projection_option.
      subst. case_decide; [|contradiction].
      eexists; reflexivity.
    }
    rewrite Heqx in Hmsg.
    specialize (Hmsg m eq_refl eq_refl).
    spec Hmsg. { subst x. assumption. }
    destruct Hmsg as [Hseed | [item [Hitem [Hout Hsub_item]]]]
    ; [apply (initial_message_is_valid Xj); right; assumption|].
    apply (valid_trace_output_is_valid Xj _ _ IHtr).
    apply Exists_exists.
    specialize
      (@pre_VLSM_projection_transition_item_project_is_Some _ (composite_type IM) _
        composite_label_sub_projection_option composite_state_sub_projection
        item Hsub_item)
      as [itemX HitemX].
    exists itemX.
    split.
    + apply elem_of_map_option. exists item.
      split; assumption.
    + unfold pre_VLSM_projection_transition_item_project in HitemX.
      destruct (composite_label_sub_projection_option _); [|congruence].
      inversion HitemX.
      assumption.
  - clear -Hmsg Sub_Free finite_index Hlst His IHtr.
    destruct iom as [m|]; [|exact I].
    simpl in *.
    remember {| input := Some m |} as x.
    assert (Hx : from_sub_projection x).
    { unfold from_sub_projection at 1, pre_VLSM_projection_in_projection, composite_label_sub_projection_option.
      subst. case_decide; [|contradiction].
      eexists; reflexivity.
    }
     specialize (Hmsg tr x []). rewrite Heqx in Hmsg.
    specialize (Hmsg m eq_refl eq_refl).
    spec Hmsg. { subst; assumption. }
    destruct Hmsg as [Hseed | [item [Hitem [Hout Hsub_item]]]]
    ; [right; assumption|].
    left.
    remember (finite_trace_last (composite_state_sub_projection _) _) as lst.
    specialize (proper_sent Sub_Free lst (HasBeenSentCapability := Sub_Free_HasBeenSentCapability)) as Hproper.
    assert (Hlstp : valid_state_prop (pre_loaded_with_all_messages_vlsm Sub_Free) lst).
    { revert Hlst. apply VLSM_incl_valid_state.  apply Xj_incl_Pre_Sub_Free.  }
    spec Hproper Hlstp.
    apply Hproper.
    apply has_been_sent_consistency; [apply Sub_Free_HasBeenSentCapability| assumption| ].
    exists (composite_state_sub_projection s), (finite_trace_sub_projection tr).
    split.
    { split;[|assumption].
       apply (VLSM_incl_finite_valid_trace_from_to Xj_incl_Pre_Sub_Free).
       apply valid_trace_add_last.
       assumption.
       symmetry;assumption.
    }
    unfold trace_has_message.
    apply Exists_exists.
    specialize
      (@pre_VLSM_projection_transition_item_project_is_Some _ (composite_type IM) _
        composite_label_sub_projection_option composite_state_sub_projection
        item Hsub_item)
      as [itemX HitemX].
    exists itemX.
    split.
    + apply elem_of_map_option. exists item.
      split; assumption.
    + unfold pre_VLSM_projection_transition_item_project in HitemX.
      destruct (composite_label_sub_projection_option _); [|congruence].
      inversion HitemX.
      assumption.
Qed.

Lemma valid_state_sub_projection
  (s : state)
  (Hs : state_sub_item_input_is_seeded_or_sub_previously_sent s)
  (Hps : valid_state_prop X s)
  : valid_state_prop Xj (composite_state_sub_projection s).
Proof.
  apply valid_state_has_trace in Hps.
  destruct Hps as [is [tr Htr]].
  specialize (Hs _ _ (VLSM_incl_finite_valid_trace_init_to X_incl_Pre _ _ _ Htr)).
  apply valid_trace_get_last in Htr as Hlst.
  apply valid_trace_forget_last in Htr.
  specialize (finite_trace_sub_projection_last_state _ _ (proj1 Htr)) as Hlst'.
  apply (finite_valid_trace_sub_projection _ _ Hs) in Htr as Hptr.
  - destruct Hptr as [Hptr _]. apply finite_valid_trace_last_pstate in Hptr.
    simpl in *.
    rewrite Hlst' in Hptr.
    subst. assumption.
Qed.

Lemma finite_valid_trace_from_sub_projection
  (s : composite_state IM)
  (tr : list (composite_transition_item IM))
  (lst := finite_trace_last s tr)
  (Hmsg : state_sub_item_input_is_seeded_or_sub_previously_sent lst)
  (Htr : finite_valid_trace_from X s tr)
  : finite_valid_trace_from Xj (composite_state_sub_projection s) (finite_trace_sub_projection tr).
Proof.
  apply finite_valid_trace_from_complete_left in Htr.
  destruct Htr as [is [pre [Htr Hs]]].
  assert (Hpre := proj1 Htr).
  apply finite_valid_trace_from_app_iff in Hpre.
  destruct Hpre as [Hpre _].
  specialize (finite_trace_sub_projection_last_state _ _ Hpre) as Hpre_lst.
  apply finite_valid_trace_sub_projection in Htr.
  - destruct Htr as [Htr His].
    rewrite finite_trace_sub_projection_app in Htr.
    apply finite_valid_trace_from_app_iff in Htr.
    destruct Htr as [_ Htr].
    subst s. simpl in *.
    rewrite Hpre_lst in Htr. assumption.
  - specialize (Hmsg is (pre ++ tr)).
    apply Hmsg.
    apply (VLSM_incl_finite_valid_trace_init_to X_incl_Pre).
    apply valid_trace_add_last.
    assumption.
    rewrite finite_trace_last_app.
    unfold lst. subst. reflexivity.
Qed.

End sub_projection_with_no_equivocation_constraints.

Lemma lift_sub_state_initial
  (s : composite_state sub_IM)
  (Hs : composite_initial_state_prop sub_IM s)
  : composite_initial_state_prop IM (lift_sub_state s).
Proof.
  intros i.
  unfold lift_sub_state, lift_sub_state_to.
  case_decide.
  - specialize (Hs (dec_exist _ i H)).
    assumption.
  - destruct (vs0 _). assumption.
Qed.

Lemma lift_sub_state_to_initial
  (s0 : composite_state IM)
  (Hs0 : composite_initial_state_prop IM s0)
  (s : composite_state sub_IM)
  (Hs : composite_initial_state_prop sub_IM s)
  : composite_initial_state_prop IM (lift_sub_state_to s0 s).
Proof.
  intros i.
  unfold lift_sub_state_to.
  case_decide.
  - specialize (Hs (dec_exist _ i H)).
    assumption.
  - apply Hs0.
Qed.

Lemma lift_sub_message_initial
  (m : message)
  (Hm : composite_initial_message_prop sub_IM m)
  : composite_initial_message_prop IM m.
Proof.
  destruct Hm as [[i Hi] Hm].
  unfold sub_IM in Hm. simpl in Hm.
  exists i.
  assumption.
Qed.

Lemma lift_sub_valid l s om
  (Hv: composite_valid sub_IM l (s, om))
  : composite_valid IM (lift_sub_label l) (lift_sub_state s, om).
Proof.
  revert Hv.
  destruct l as (sub_i, li).
  destruct_dec_sig sub_i i H Heqsub_i.
  simpl.
  unfold vvalid. unfold lift_sub_state, lift_sub_state_to.
  simpl.
  subst. simpl.
  unfold sub_IM in li. simpl in li.
  case_decide; [|contradiction].
  match goal with
  |- valid _ (s ?i1, _) -> valid _ (s ?i2, _)
    => replace (s i1) with (s i2)
  end; [exact id|].
  apply sub_IM_state_pi.
Qed.

Lemma lift_sub_transition l s om s' om'
  (Ht: composite_transition sub_IM l (s, om) = (s', om'))
  : composite_transition IM
    (lift_sub_label l) (lift_sub_state s, om) = (lift_sub_state s', om').
Proof.
  revert Ht.
  destruct l as (sub_i, li).
  destruct_dec_sig sub_i i Hi Heqsub_i.
  simpl.
  unfold vtransition. unfold lift_sub_state at 1. unfold lift_sub_state_to.
  simpl.
  subst. simpl.
  unfold sub_IM in li. simpl in li.
  case_decide; [|contradiction].
  replace (s (dec_exist sub_index_prop i H)) with (s (dexist i Hi))
    by apply sub_IM_state_pi.
  clear H.
  destruct (transition _ _) as (si', _om').
  inversion_clear 1.
  f_equal.
  apply functional_extensionality_dep_good.
  intros j.
  destruct (decide (i = j)).
  - subst.
    rewrite state_update_eq.
    unfold lift_sub_state, lift_sub_state_to. simpl.
    case_decide; [|contradiction].
    rewrite sub_IM_state_update_eq.
    reflexivity.
  - rewrite state_update_neq by congruence.
    unfold lift_sub_state, lift_sub_state_to. simpl.
    case_decide; [|reflexivity].
    rewrite state_update_neq; [reflexivity|].
    intro contra. apply dec_sig_eq_iff in contra. simpl in contra. congruence.
Qed.

End sub_composition.

(** ** Lifting a trace from a sub-composition to the full composition

In this section we first show that given a valid state for a composition of
all nodes we can reset some of its state-components to initial states for those
components without losing the valid state property.

The set of nodes for which the reset operation will happen is <<equivocators>>.

We then show that a similar result holds for replacing the equivocator
components with the components corresponding to any valid state of the
composition of just the equivocators.

We proving those results for compositions pre-loaded with all messages
(Lemmas [reset_equivocating_transitions_preloaded_projection] and
[PreSubFree_PreFree_weak_full_projection]).
*)

Section lift_sub_state_to_preloaded.

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (equivocators : list index)
  (Free := free_composite_vlsm IM)
  (PreFree := pre_loaded_with_all_messages_vlsm Free)
  (equivocating_IM := sub_IM IM equivocators )
  (SubFree : VLSM message :=  free_composite_vlsm equivocating_IM)
  (PreSubFree := pre_loaded_with_all_messages_vlsm SubFree)
  (base_s : composite_state IM)
  (Hbase_s : valid_state_prop PreFree base_s)
  .

(** A partial label projection function which only keeps non-equivocating transitions.
*)
Definition remove_equivocating_label_project (l : composite_label IM) : option (composite_label IM)
  := if decide (projT1 l ∈ equivocators) then None else Some l.

(** Replaces the state components of the given state with those of <<eqv_is>>.
*)
Definition remove_equivocating_state_project eqv_is
  : composite_state IM -> composite_state IM
  := fun s => lift_sub_state_to IM equivocators s eqv_is.

Lemma remove_equivocating_strong_projection_valid_preservation eqv_is
  : strong_projection_valid_preservation Free Free remove_equivocating_label_project (remove_equivocating_state_project eqv_is).
Proof.
  intros lX lY Hl s om Hv.
  destruct lX as (i, liX).
  unfold remove_equivocating_label_project in Hl.
  simpl in Hl.
  destruct (decide _); [congruence|].
  inversion Hl. subst lY. clear Hl.
  apply proj1 in Hv.
  split; [|exact I].
  cbn in Hv |- *.
  unfold remove_equivocating_state_project.
  rewrite lift_sub_state_to_neq; assumption.
Qed.

Lemma remove_equivocating_strong_projection_transition_preservation_Some eqv_is
  : strong_projection_transition_preservation_Some Free Free remove_equivocating_label_project (remove_equivocating_state_project eqv_is).
Proof.
  intros lX lY Hl s om s' om' Ht.
  destruct lX as (i, liX).
  unfold remove_equivocating_label_project in Hl.
  simpl in Hl.
  destruct (decide _); [congruence|].
  inversion Hl. subst lY. clear Hl.
  cbn in Ht |- *.
  unfold remove_equivocating_state_project.
  rewrite lift_sub_state_to_neq by assumption.
  destruct (vtransition _ _ _) as (si', _om').
  inversion_clear Ht.
  f_equal.
  apply functional_extensionality_dep.
  intro j.
  destruct (decide (i = j)).
  - subst. rewrite state_update_eq.
    rewrite lift_sub_state_to_neq by assumption.
    rewrite state_update_eq.
    reflexivity.
  - rewrite state_update_neq by congruence.
    unfold lift_sub_state_to.
    case_decide; [reflexivity|].
    rewrite state_update_neq by congruence.
    reflexivity.
Qed.

Lemma remove_equivocating_strong_projection_transition_consistency_None eqv_is
  : @strong_projection_transition_consistency_None _ Free _ remove_equivocating_label_project (remove_equivocating_state_project eqv_is).
Proof.
  intros lX Hl s om s' om' Ht.
  destruct lX as (i, liX).
  unfold remove_equivocating_label_project in Hl.
  simpl in Hl.
  case_decide; [|congruence]. clear Hl.
  cbn in Ht.
  destruct (vtransition _ _ _) as (si', _om').
  inversion_clear Ht.
  apply functional_extensionality_dep.
  intro j.
  unfold remove_equivocating_state_project.
  unfold lift_sub_state_to.
  case_decide; [reflexivity|].
  apply state_update_neq.
  intro. subst. contradiction.
Qed.

Lemma remove_equivocating_strong_full_projection_initial_state_preservation eqv_is
  (Heqv_is : composite_initial_state_prop (sub_IM IM equivocators) eqv_is)
  : strong_full_projection_initial_state_preservation Free Free (remove_equivocating_state_project eqv_is).
Proof.
  intros s Hs i.
  unfold remove_equivocating_state_project, lift_sub_state_to.
  destruct (decide _).
  - exact (Heqv_is (dec_exist _ i s0)).
  - exact (Hs i).
Qed.

(**
Given any valid trace for the composition of all nodes and an initial state
for the composition of just the equivocators, the trace obtained by resetting
the components corresponding to the equivocators to those of the given initial
state and removing the transitions corresponding to the equivocators is
still a valid trace.
*)
Lemma remove_equivocating_transitions_preloaded_projection eqv_is
  (Heqv_is : composite_initial_state_prop (sub_IM IM equivocators) eqv_is)
  : VLSM_projection PreFree PreFree remove_equivocating_label_project (remove_equivocating_state_project eqv_is).
Proof.
  apply basic_VLSM_projection_preloaded.
  - apply remove_equivocating_strong_projection_valid_preservation.
  - apply remove_equivocating_strong_projection_transition_preservation_Some.
  - apply remove_equivocating_strong_projection_transition_consistency_None.
  - apply remove_equivocating_strong_full_projection_initial_state_preservation.
    assumption.
Qed.

Lemma preloaded_lift_sub_state_to_initial_state
  : weak_full_projection_initial_state_preservation PreSubFree PreFree (lift_sub_state_to IM equivocators base_s).
Proof.
  apply valid_state_has_trace in Hbase_s as Htr.
  destruct Htr as [is [tr Htr]].
  intros eqv_is Heqv_is.
  apply (VLSM_projection_finite_valid_trace_init_to (remove_equivocating_transitions_preloaded_projection _ Heqv_is)) in Htr.
  apply valid_trace_last_pstate in Htr. assumption.
Qed.

Lemma lift_sub_to_valid l s om
  (Hv: composite_valid (sub_IM IM equivocators) l (s, om))
  : composite_valid IM (lift_sub_label IM equivocators l) (lift_sub_state_to IM equivocators base_s s, om).
Proof.
  revert Hv. destruct l as (i, li).
  destruct_dec_sig i j Hj Heq. subst i.
  simpl. unfold equivocating_IM, sub_IM. simpl.
  rewrite lift_sub_state_to_eq with (Hi := Hj). exact id.
Qed.

Lemma lift_sub_to_transition l s om s' om'
  (Ht: composite_transition (sub_IM IM equivocators) l (s, om) = (s', om'))
  : composite_transition IM
    (lift_sub_label IM equivocators l) (lift_sub_state_to IM equivocators base_s s, om) =
    (lift_sub_state_to IM equivocators base_s s', om').
Proof.
  destruct l as (i, li).
  destruct_dec_sig i j Hj Heq. subst i.
  revert Ht. unfold vtransition. simpl. unfold vtransition. simpl.
  rewrite lift_sub_state_to_eq with (Hi := Hj).
  destruct (transition _ _) as (si', _om').
  inversion_clear 1.
  f_equal.
  apply functional_extensionality_dep. intro i.
  destruct (decide (i = j)).
  - subst.
    rewrite lift_sub_state_to_eq with (Hi := Hj).
    rewrite! state_update_eq. reflexivity.
  - rewrite state_update_neq by congruence.
    destruct (decide (i ∈ equivocators)).
    + rewrite !lift_sub_state_to_eq with (Hi := e).
      rewrite state_update_neq; [reflexivity|].
      intro Hcontra. apply dsig_eq in Hcontra. contradiction.
    + rewrite !lift_sub_state_to_neq by assumption. reflexivity.
Qed.

(**
Given any valid state for the composition of all nodes and a valid trace
for the composition of just the equivocators, the trace obtained by completing
the state-components from the trace with the components from the given
valid state is a valid trace for the composition of all nodes.
**)
Lemma PreSubFree_PreFree_weak_full_projection
  : VLSM_weak_full_projection PreSubFree PreFree (lift_sub_label IM equivocators) (lift_sub_state_to IM equivocators base_s).
Proof.
  apply basic_VLSM_weak_full_projection; intro; intros.
  - split; [|exact I].
    apply lift_sub_to_valid. apply Hv.
  - apply lift_sub_to_transition. apply H.
  - apply preloaded_lift_sub_state_to_initial_state; assumption.
  - apply any_message_is_valid_in_preloaded.
Qed.

(** If the composition constraint only depends on the projection sub-state,
then valid traces of the [induced_sub_projection] can be lifted to valid traces
of the constrained composition.
*)
Lemma induced_sub_projection_lift
  (constraint : composite_label IM -> composite_state IM * option message -> Prop)
  (Hconstraint_consistency :
    forall s1 s2,
      composite_state_sub_projection IM equivocators s1 = composite_state_sub_projection IM equivocators s2 ->
      forall l om, constraint l (s1, om) -> constraint l (s2, om)
    )
  : VLSM_full_projection
    (induced_sub_projection IM equivocators constraint)
    (composite_vlsm IM constraint)
    (lift_sub_label IM equivocators)
    (lift_sub_state IM equivocators).
Proof.
  apply basic_VLSM_full_projection; intro; intros.
  - destruct Hv as [_ [_ [[i li] [sX [Heql [Heqs [HsX [Hom [Hv Hc]]]]]]]]].
    cbn in Hv, Hc.
    unfold composite_label_sub_projection_option in Heql.
    simpl in Heql.
    case_decide; [|congruence].
    inversion Heql. subst l. clear Heql.
    cbn. unfold constrained_composite_valid. cbn.
    unfold lift_sub_state.
    rewrite lift_sub_state_to_eq with (Hi := H).
    subst.
    split; [assumption|].
    revert Hc.
    apply Hconstraint_consistency.
    symmetry.
    apply composite_state_sub_projection_lift_to.
  - apply proj2 in H. revert H. cbn.
    destruct (vtransition _ _ _) as (si', _om').
    inversion 1. subst. clear H.
    f_equal.
    extensionality i.
    destruct l as (sub_j, lj).
    destruct_dec_sig sub_j j Hj Heqsub_j.
    subst.
    simpl.
    destruct (decide (i = j)).
    + subst. rewrite state_update_eq.
      unfold lift_sub_state.
      rewrite lift_sub_state_to_eq with (Hi := Hj).
      unfold composite_state_sub_projection.
      simpl.
      rewrite state_update_eq.
      reflexivity.
    + rewrite state_update_neq by congruence.
      destruct (decide (i ∈ equivocators)).
      * unfold lift_sub_state.
        rewrite !lift_sub_state_to_eq with (Hi := e).
        unfold composite_state_sub_projection. simpl.
        rewrite state_update_neq by congruence.
        rewrite lift_sub_state_to_eq with (Hi := e).
        reflexivity.
      * unfold lift_sub_state, lift_sub_state_to.
        destruct (decide _); [contradiction|reflexivity].
  - apply (lift_sub_state_initial IM).
    destruct H as [sX [<- HsX]].
    intro sub_i.
    destruct_dec_sig sub_i i Hi Heqsub_i.
    subst. apply HsX.
  - assumption.
Qed.

(** A specialization of [basic_projection_induces_friendliness] for
[induced_sub_projection]s.
*)
Lemma induced_sub_projection_friendliness
  (constraint : composite_label IM -> composite_state IM * option message -> Prop)
  (Hlift_proj : VLSM_full_projection
    (induced_sub_projection IM equivocators constraint)
    (composite_vlsm IM constraint)
    (lift_sub_label IM equivocators)
    (lift_sub_state IM equivocators))
  : projection_friendly_prop (induced_sub_projection_is_projection IM equivocators constraint).
Proof.
  eapply (basic_projection_induces_friendliness (composite_vlsm IM constraint)).
  assumption.
  Unshelve.
  - apply induced_sub_projection_transition_consistency_None.
  - apply composite_label_sub_projection_option_lift.
  - apply composite_state_sub_projection_lift.
  - apply induced_sub_projection_transition_consistency_Some.
Qed.

End lift_sub_state_to_preloaded.

Section sub_composition_incl.

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (indices1 indices2 : list index)
  (Hincl : indices1 ⊆ indices2)
  (sub_IM1 := sub_IM IM indices1)
  (sub_IM2 := sub_IM IM indices2)
  (sub_index1_prop_dec : forall i, Decision (sub_index_prop indices1 i) := fun i => sub_index_prop_dec indices1 i)
  (sub_index2_prop_dec : forall i, Decision (sub_index_prop indices2 i) := fun i => sub_index_prop_dec indices2 i)
  .

Definition lift_sub_incl_state
  (s : composite_state sub_IM1)
  : composite_state sub_IM2
  := fun sub_i2 =>
    let i := proj1_sig sub_i2 in
    match @decide  (sub_index_prop indices1 i) (sub_index1_prop_dec i) with
    | left e =>  s (dec_exist _ i e)
    | _ => proj1_sig (vs0 (IM i))
    end.

Lemma lift_sub_incl_state_initial
  (s : composite_state sub_IM1)
  (Hs : composite_initial_state_prop sub_IM1 s)
  : composite_initial_state_prop sub_IM2 (lift_sub_incl_state s).
Proof.
  intros [i Hi].
  unfold lift_sub_incl_state.
  case_decide.
  - specialize (Hs (dec_exist _ i H)).
    assumption.
  - destruct (vs0 _). assumption.
Qed.

Lemma lift_sub_incl_message_initial
  (m : message)
  (Hm : composite_initial_message_prop sub_IM1 m)
  : composite_initial_message_prop sub_IM2 m.
Proof.
  destruct Hm as [[i Hi] Hm].
  unfold sub_IM1, sub_IM in Hm. simpl in Hm.
  apply bool_decide_spec, Hincl in Hi.
  exists (dexist i Hi).
  assumption.
Qed.

Definition lift_sub_incl_label
  (l : composite_label sub_IM1)
  : composite_label sub_IM2
  :=
  let sub1_i := projT1 l in
  let i := dec_proj1_sig sub1_i in
  let H1i := dec_proj2_sig sub1_i in
  let H2i := Hincl _ H1i in
  let  sub2_i := @dec_exist _ _ sub_index2_prop_dec i H2i in
  existT sub2_i (projT2 l).

Lemma lift_sub_incl_valid l s om
  (Hv: composite_valid (sub_IM IM indices1) l (s, om))
  : composite_valid (sub_IM IM indices2) (lift_sub_incl_label l) (lift_sub_incl_state s, om).
Proof.
  revert Hv.
  destruct l as (sub1_i, li).
  destruct_dec_sig sub1_i i H Heqsub1_i.
  simpl.
  unfold vvalid. unfold lift_sub_incl_state.
  simpl.
  subst. simpl.
  unfold sub_IM in li. simpl in li.
  destruct (decide (sub_index_prop indices1 i))
  ; [|contradiction].
  match goal with
  |- valid _ (s ?i1, _) -> valid _ (s ?i2, _)
    => replace (s i1) with (s i2)
  end; [exact id|].
  apply sub_IM_state_pi.
Qed.

Lemma lift_sub_incl_transition l s om s' om'
  (Ht: composite_transition (sub_IM IM indices1) l (s, om) = (s', om'))
  : composite_transition (sub_IM IM indices2)
    (lift_sub_incl_label l) (lift_sub_incl_state s, om) = (lift_sub_incl_state s', om').
Proof.
  revert Ht.
  destruct l as (sub1_i, li).
  destruct_dec_sig sub1_i i Hi Heqsub1_i.
  simpl.
  unfold vtransition. unfold lift_sub_incl_state at 1.
  simpl.
  subst. simpl.
  unfold sub_IM in li. simpl in li.
  destruct (decide (sub_index_prop indices1 i))
  ; [|contradiction].
  replace (s (dec_exist (sub_index_prop indices1) i s0)) with (s (dexist i Hi))
    by apply sub_IM_state_pi.
  clear s0.
  destruct (transition _ _) as (si', _om').
  intro Ht. inversion Ht. subst. clear Ht.
  f_equal.
  apply functional_extensionality_dep_good.
  intros sub2_j.
  destruct_dec_sig sub2_j j Hj Heqsub2_j.
  subst.
  destruct (decide (i = j)).
  - subst.
    specialize (sub_IM_state_update_eq IM indices2 j (lift_sub_incl_state s) si'
    (Hincl j (dec_proj2_sig (@dec_exist _ _ sub_index1_prop_dec j Hi))) Hj) as Hrew.
    match goal with
    |- ?s1 = _ => replace s1 with si'
    end.
    unfold lift_sub_incl_state. simpl.
    destruct (decide _); [|contradiction].
    rewrite sub_IM_state_update_eq. reflexivity.
  - rewrite state_update_neq
    ; [| intro H; apply dec_sig_eq_iff in H; simpl in H; congruence].
    unfold lift_sub_incl_state. simpl.
    destruct (decide _); [|reflexivity].
    rewrite state_update_neq; [reflexivity|].
    intro H. apply dec_sig_eq_iff in H. simpl in H. congruence.
Qed.

Lemma lift_sub_incl_full_projection
  : VLSM_full_projection (free_composite_vlsm sub_IM1) (free_composite_vlsm sub_IM2) lift_sub_incl_label lift_sub_incl_state.
Proof.
  apply basic_VLSM_strong_full_projection; intro; intros.
  - split; [|exact I].
    apply lift_sub_incl_valid. apply H.
  - apply lift_sub_incl_transition. assumption.
  - apply lift_sub_incl_state_initial. assumption.
  - apply lift_sub_incl_message_initial. assumption.
Qed.

Lemma lift_sub_incl_preloaded_full_projection
  (P Q : message -> Prop)
  (Hpq : forall m, P m -> Q m)
  : VLSM_full_projection (pre_loaded_vlsm (free_composite_vlsm sub_IM1) P) (pre_loaded_vlsm (free_composite_vlsm sub_IM2) Q) lift_sub_incl_label lift_sub_incl_state.
Proof.
  apply basic_VLSM_full_projection_preloaded_with; [assumption|..]; intro; intros.
  - split; [|exact I].
    apply lift_sub_incl_valid. apply H.
  - apply lift_sub_incl_transition. assumption.
  - apply lift_sub_incl_state_initial. assumption.
  - apply lift_sub_incl_message_initial. assumption.
Qed.

End sub_composition_incl.

Section sub_composition_sender.

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  indices
  (sub_IM := sub_IM IM indices)
  (sub_index_prop_dec : forall i, Decision (sub_index_prop indices i) := sub_index_prop_dec indices)
  {validator : Type}
  (A : validator -> index)
  (sender : message -> option validator)
  (Hsender_safety : sender_safety_alt_prop IM A sender)
  .

(** If a sub-composition [can_emit] a message then its sender must be one of
the components of the sub-composition.
*)
Lemma sub_can_emit_sender (P : message -> Prop)
  : forall m v,
    sender m = Some v ->
    can_emit (pre_loaded_vlsm (free_composite_vlsm sub_IM) P)  m ->
    A v ∈ indices.
Proof.
  intros m v Hsender Hemit.
  specialize (Hsender_safety m v Hsender).
  destruct Hemit as [(s, om) [(sub_i, li) [s' Ht]]].
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst. unfold sub_IM, SubProjectionTraces.sub_IM in li. simpl in li.
  specialize (PreSubFree_PreFree_weak_full_projection IM indices (proj1_sig (composite_s0 IM)))
    as Hproj.
  spec Hproj.
  { apply initial_state_is_valid. destruct (composite_s0 IM). assumption. }
  apply
    (VLSM_incl_input_valid_transition
      (pre_loaded_vlsm_incl_pre_loaded_with_all_messages (free_composite_vlsm sub_IM) P))
    in Ht.
  apply (VLSM_weak_full_projection_input_valid_transition Hproj) in Ht.
  clear Hproj.
  specialize (ProjectionTraces.preloaded_component_projection IM i)
    as Hproj.
  remember (lift_sub_state_to _ _ _ s) as sX.
  remember (lift_sub_state_to _ _ _ s') as sX'.
  remember (lift_sub_label _ _ _) as lX.
  specialize (VLSM_projection_input_valid_transition Hproj lX li) as Hproj_t.
  subst lX. unfold lift_sub_label in Hproj_t.
  simpl in Hproj_t.
  spec Hproj_t.
  { unfold ProjectionTraces.composite_project_label.
    simpl.
    case_decide; [|congruence].
    replace H with (eq_refl (A := index) (x := i))
    ; [reflexivity|].
    apply Eqdep_dec.UIP_dec.
    assumption.
  }
  specialize (Hproj_t _ _ _ _ Ht).
  specialize (Hsender_safety i).
  spec Hsender_safety. { eexists _, _, _. exact Hproj_t. }
  rewrite Hsender_safety. assumption.
Qed.

(** *** Sender and sender-safety specialized for the subcomposition *)

Definition sub_IM_sender (m : message)
  : option (dsig (fun v => A v ∈ indices)) :=
  match sender m with
  | None => None
  | Some v =>
    match (decide (A v ∈ indices)) with
    | left Av_in => Some (dec_exist (fun v => A v ∈ indices) v Av_in)
    | _ => None
    end
  end.

Definition sub_IM_A
  (v : dsig (fun v => A v ∈ indices))
  : sub_index indices :=
  dexist (A (proj1_sig v)) (proj2_dsig v).

Lemma sub_IM_preserves_channel_authentication
  : channel_authentication_prop IM A sender ->
    channel_authentication_prop sub_IM sub_IM_A sub_IM_sender.
Proof.
  intros Hsigned sub_i m Hemit.
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst.
  apply Hsigned in Hemit.
  unfold channel_authenticated_message in *.
  simpl in Hemit.
  unfold sub_IM_sender.
  destruct (sender m) as [v|]; [|simpl in Hemit; congruence].
  apply Some_inj in Hemit. subst.
  case_decide; [|contradiction].
  simpl.
  f_equal.
  apply dec_sig_eq_iff; intuition.
Qed.

Lemma sub_IM_preserves_no_initial_messages
  : no_initial_messages_in_IM_prop IM ->
    no_initial_messages_in_IM_prop sub_IM.
Proof.
  intros Hno_init sub_i m.
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst.
  apply Hno_init.
Qed.

Lemma sub_IM_sender_safety
  : sender_safety_alt_prop sub_IM sub_IM_A sub_IM_sender.
Proof.
  intros m sub_v Hsender sub_i Hm.
  destruct_dec_sig sub_v v HAv Heqsub_v.
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst.
  unfold sub_IM_A.
  apply dsig_eq. simpl.
  apply (Hsender_safety m v).
  - clear -Hsender.
    unfold sub_IM_sender in Hsender.
    destruct (sender m) as [_v|] eqn:Hsender_v; [|congruence].
    case_decide; [|congruence].
    inversion Hsender; intuition.
  - clear -Hm.
    revert Hm.
    unfold sub_IM, SubProjectionTraces.sub_IM. simpl.
    exact id.
Qed.

Context
  (sub_IM_Hbs : forall sub_i, HasBeenSentCapability (sub_IM sub_i))
  .

Lemma sub_IM_has_been_sent_iff_by_sender s
  (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm (free_composite_vlsm sub_IM)) s)
  m v
  (Hsender : sender m = Some v)
  (Hv : A v ∈ indices)
  : composite_has_been_sent sub_IM sub_IM_Hbs s m ->
    @has_been_sent _ _ (sub_IM_Hbs (dexist (A v) Hv)) (s (dexist (A v) Hv)) m.
Proof.
  apply valid_state_has_trace in Hs as Htr.
  destruct Htr as [is [tr Htr]].
  specialize
    (has_been_sent_iff_by_sender sub_IM
      sub_IM_Hbs sub_IM_sender_safety Htr)
    as Hsent_m.
  specialize (Hsent_m m (dec_exist (fun v => A v ∈ indices) _ Hv)).
  spec Hsent_m.
  { unfold sub_IM_sender. rewrite Hsender.
    case_decide; [|contradiction].
    f_equal.
    apply dsig_eq; intuition.
  }
  rewrite Hsent_m.
  clear -Hsender Hs.
  unfold sub_IM_A, sub_IM.
  cbn.
  remember (s (dexist _ _)) as sAv.
  replace sAv with (s (dexist (A v) Hv))
    by (subst; apply (sub_IM_state_pi IM)).
  apply has_been_sent_irrelevance.
  subst.
  apply (preloaded_valid_state_projection sub_IM (dec_exist (sub_index_prop indices) (A v) Hv))
    in Hs.
  assumption.
Qed.

(** ** No-equivocation results for sub-composition *)

(** Constraining (only) a subset of the nodes of a composition to not message-
equivocate.
*)
Definition sub_IM_not_equivocating_constraint
  (l : composite_label IM)
  (som : composite_state IM * option message)
  : Prop :=
  let (s, om) := som in
  match om with
  | None => True
  | Some m =>
    match option_map A (sender m) with
    | None => True
    | Some i =>
      match decide (i ∈ indices) with
      | left non_byzantine_i =>
        let sub_i := dec_exist (sub_index_prop indices) i non_byzantine_i in
        @has_been_sent _ _ (sub_IM_Hbs sub_i) (s i) m
      | _ => True
      end
    end
  end.

Definition non_sub_index_authenticated_message (m : message) : Prop :=
  exists i, i ∉ indices /\ channel_authenticated_message A sender i m.

Context
  (no_initial_messages_in_IM : no_initial_messages_in_IM_prop IM)
  (can_emit_signed : channel_authentication_prop IM A sender)
  .

Lemma induced_sub_projection_valid_preservation constraint l s om
  (Hv : vvalid (induced_sub_projection IM indices constraint) l (s, om))
  : composite_valid sub_IM l (s, om).
Proof.
  destruct Hv as [lX [sX [Heql [Heqs [HsX [Hom [Hv Hc]]]]]]].
  revert Hv.
  destruct lX as (i, lXi).
  unfold composite_label_sub_projection_option in Heql.
  simpl in Heql.
  case_decide; [|congruence].
  inversion Heql. subst. clear Heql.
  exact id.
Qed.

Lemma induced_sub_projection_transition_preservation [constraint]
  : forall l s om s' om',
  vtransition (induced_sub_projection IM indices constraint) l (s, om) = (s', om') <->
  composite_transition sub_IM l (s, om) = (s', om').
Proof.
  intros.
  destruct l as (sub_i, li).
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst.
  cbn. unfold sub_IM at 6. simpl.
  unfold lift_sub_state at 1. rewrite lift_sub_state_to_eq with (Hi0 := Hi).
  destruct (vtransition _ _ _) as (si', _om').
  split; inversion 1; subst; clear H; f_equal; extensionality sub_j
  ; destruct_dec_sig sub_j j Hj Heqsub_j
  ; subst sub_j
  ; unfold composite_state_sub_projection
  ; simpl
  ; unfold sub_IM
  ; (destruct (decide (i = j))
    ; [subst; rewrite state_update_eq, sub_IM_state_update_eq; reflexivity|])
  ; rewrite (state_update_neq _ (lift_sub_state _ _ _)) by congruence
  ; rewrite state_update_neq by (setoid_rewrite dsig_eq; simpl; congruence)
  ; unfold lift_sub_state
  ; rewrite lift_sub_state_to_eq with (Hi0 := Hj)
  ; intuition.
Qed.

Lemma sub_IM_no_equivocation_preservation
  l s om
  (Hv : vvalid (induced_sub_projection IM indices sub_IM_not_equivocating_constraint)
    l (s, om))
  : composite_no_equivocations_except_from sub_IM sub_IM_Hbs
      non_sub_index_authenticated_message l (s, om).
Proof.
  destruct om as [m|]; [|exact I].
  destruct Hv as [lX [sX [_ [Heqs [_ [Hm [_ Hc]]]]]]].
  cbn in Hc |- *.
  specialize
    (composite_no_initial_valid_messages_have_sender IM A sender
      can_emit_signed no_initial_messages_in_IM _ _ Hm)
    as Hhas_sender.
  destruct (sender m) as [v|] eqn:Hsender; [|congruence].
  clear Hhas_sender.
  simpl in Hc.
  apply (emitted_messages_are_valid_iff (composite_vlsm IM sub_IM_not_equivocating_constraint) m)
    in Hm as [[i [[im Him] Heqm]] | Hemitted].
  - exfalso. clear -no_initial_messages_in_IM Him.
    elim (no_initial_messages_in_IM i im); assumption.
  - apply (VLSM_incl_can_emit (constraint_preloaded_free_incl _ _)) in Hemitted.
    specialize (can_emit_projection IM A sender Hsender_safety (A v) m) as Hemit.
    spec Hemit; [rewrite Hsender; intuition|].
    apply Hemit in Hemitted. clear Hemit.
    case_decide.
    + left. subst.
      eexists; exact Hc.
    + right. exists (A v). split; [assumption|].
      unfold channel_authenticated_message.
      rewrite Hsender; intuition.
Qed.

End sub_composition_sender.

Section sub_composition_all.
(** ** A subcomposition with all the components

If taking the subset of indices used for the sub-composition to be the entire
set of indices, the obtained sub-composition is trace-equivalent with the
original composition.
*)

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  {finite_index : finite.Finite index}
  .

Context
  (sub_IM := sub_IM IM (enum index))
  .

Program Definition free_sub_free_index (i : index) : sub_index (enum index) :=
  dec_exist _ i _.
Next Obligation.
  intros. apply elem_of_enum.
Qed.

Definition free_sub_free_label (l : composite_label IM) : composite_label sub_IM :=
  let (i, li) := l in
  existT (free_sub_free_index i) li.

Definition free_sub_free_state (sub_s : composite_state sub_IM) : composite_state IM :=
  fun i => sub_s (free_sub_free_index i).

Definition free_sub_free_constraint
  (constraint : composite_label IM -> composite_state IM * option message -> Prop)
  : composite_label sub_IM -> composite_state sub_IM * option message -> Prop
  := fun l som => let (s, om) := som in
    constraint (lift_sub_label IM (enum index) l) (free_sub_free_state s, om).

Context
  (constraint : composite_label IM -> composite_state IM * option message -> Prop)
  (X := composite_vlsm IM constraint)
  (SubX := composite_vlsm sub_IM (free_sub_free_constraint constraint))
  .

Lemma preloaded_sub_composition_all_full_projection
  (seed : message -> Prop)
  : VLSM_full_projection (pre_loaded_vlsm X seed) (pre_loaded_vlsm SubX seed) free_sub_free_label (composite_state_sub_projection IM (enum index)).
Proof.
  apply basic_VLSM_strong_full_projection; intro; intros.
  - destruct l as (i, li). exact H.
  - destruct l as (i, li). simpl in *.
    unfold vtransition in *. simpl in *.
    unfold sub_IM, SubProjectionTraces.sub_IM at 2. simpl.
    unfold composite_state_sub_projection at 1. simpl.
    destruct (vtransition _ _ _) as (si', _om').
    inversion_clear H.
    f_equal.
    apply functional_extensionality_dep.
    intro sub_j.
    destruct_dec_sig sub_j j Hj Heqj. subst sub_j.
    unfold composite_state_sub_projection at 2. simpl.
    destruct (decide (i = j)).
    + subst. unfold free_sub_free_index.
      rewrite state_update_eq, sub_IM_state_update_eq. reflexivity.
    + rewrite !state_update_neq; [reflexivity|congruence|].
      intros Hcontra. apply dsig_eq in Hcontra. simpl in Hcontra. congruence.
  - specialize (composite_initial_state_sub_projection IM (enum index) _ H).
    exact id.
  - destruct H as [[i Hi] | Hseed]; [left|right; assumption].
    exists (free_sub_free_index i).
    assumption.
Qed.

Lemma sub_composition_all_full_projection
  : VLSM_full_projection X SubX free_sub_free_label (composite_state_sub_projection IM (enum index)).
Proof.
  apply basic_VLSM_strong_full_projection; intro; intros.
  - destruct l as (i, li). exact H.
  - destruct l as (i, li). simpl in *.
    unfold vtransition in *. simpl in *.
    unfold sub_IM, SubProjectionTraces.sub_IM at 2. simpl.
    unfold composite_state_sub_projection at 1. simpl.
    destruct (vtransition _ _ _) as (si', _om').
    inversion_clear H.
    f_equal.
    apply functional_extensionality_dep.
    intro sub_j.
    destruct_dec_sig sub_j j Hj Heqj. subst sub_j.
    unfold composite_state_sub_projection at 2. simpl.
    destruct (decide (i = j)).
    + subst. unfold free_sub_free_index.
      rewrite state_update_eq, sub_IM_state_update_eq. reflexivity.
    + rewrite !state_update_neq; [reflexivity|congruence|].
      intros Hcontra. apply dsig_eq in Hcontra. simpl in Hcontra. congruence.
  - specialize (composite_initial_state_sub_projection IM (enum index) _ H).
    exact id.
  - destruct H as [i Hi].
    exists (free_sub_free_index i).
    assumption.
Qed.

Lemma sub_composition_all_full_projection_rev
  : VLSM_full_projection SubX X (lift_sub_label IM (enum index)) free_sub_free_state.
Proof.
  apply basic_VLSM_strong_full_projection; intro; intros.
  - destruct l as (sub_i, li). split; [|apply H].
    destruct_dec_sig sub_i i Hi Heqi. subst sub_i.
    apply proj1 in H.
    simpl in *.
    unfold sub_IM, SubProjectionTraces.sub_IM in H. simpl in H.
    unfold free_sub_free_state.
    replace (s (free_sub_free_index i)) with (s (@dec_exist _ _ (sub_index_prop_dec (enum index)) i Hi))
    ; [assumption|].
    apply sub_IM_state_pi.
  - destruct l as (sub_i, li). simpl in *.
    destruct_dec_sig sub_i i Hi Heqi. subst sub_i.
    unfold vtransition in *. simpl in *.
    unfold sub_IM at 2, SubProjectionTraces.sub_IM in H. simpl in H.
    unfold free_sub_free_state at 1.
    replace (s (free_sub_free_index i)) with (s (@dec_exist _ _ (sub_index_prop_dec (enum index)) i Hi))
      by apply sub_IM_state_pi.
    destruct (vtransition _ _ _) as (si', _om').
    inversion_clear H.
    f_equal.
    apply functional_extensionality_dep.
    intro j.
    unfold free_sub_free_state at 2.
    destruct (decide (i = j)).
    + subst. unfold free_sub_free_index. unfold sub_IM.
      rewrite state_update_eq, sub_IM_state_update_eq. reflexivity.
    + rewrite !state_update_neq; [reflexivity| |congruence].
      intro Hcontra. apply dsig_eq in Hcontra. simpl in Hcontra. congruence.
  - intro i. specialize (H (free_sub_free_index i)). assumption.
  - destruct H as [[i Hi] Him].
    exists i. assumption.
Qed.

End sub_composition_all.

Section sub_composition_preloaded_lift.

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  indices
  (Free := free_composite_vlsm IM)
  (PreFree := pre_loaded_with_all_messages_vlsm Free)
  (SubFree := free_composite_vlsm (sub_IM IM indices))
  (PreSubFree := pre_loaded_with_all_messages_vlsm SubFree)
  .

Lemma lift_sub_free_preloaded_with_full_projection
  (seed : message -> Prop)
  : VLSM_full_projection (pre_loaded_vlsm SubFree seed) (pre_loaded_vlsm Free seed)
    (lift_sub_label IM indices) (lift_sub_state IM indices).
Proof.
  apply (basic_VLSM_full_projection_preloaded_with SubFree Free seed seed); intro; intros.
  - assumption.
  - split; [|exact I]. apply lift_sub_valid. apply H.
  - apply lift_sub_transition; assumption.
  - apply (lift_sub_state_initial IM); assumption.
  - apply (lift_sub_message_initial IM indices); assumption.
Qed.

Lemma lift_sub_free_full_projection
  : VLSM_full_projection SubFree Free
    (lift_sub_label IM indices) (lift_sub_state IM indices).
Proof.
  constructor.
  intros sX trX HtrX.
  apply (VLSM_eq_finite_valid_trace (vlsm_is_pre_loaded_with_False Free)),
    (VLSM_full_projection_finite_valid_trace (lift_sub_free_preloaded_with_full_projection _)),
    (VLSM_eq_finite_valid_trace (vlsm_is_pre_loaded_with_False SubFree)).
  assumption.
Qed.

Lemma lift_sub_preloaded_free_full_projection
  : VLSM_full_projection PreSubFree PreFree
    (lift_sub_label IM indices) (lift_sub_state IM indices).
Proof.
  constructor.
  intros sX trX HtrX.
  apply (VLSM_eq_finite_valid_trace (pre_loaded_with_all_messages_vlsm_is_pre_loaded_with_True Free)),
    (VLSM_full_projection_finite_valid_trace (lift_sub_free_preloaded_with_full_projection _)),
    (VLSM_eq_finite_valid_trace (pre_loaded_with_all_messages_vlsm_is_pre_loaded_with_True SubFree)).
  assumption.
Qed.

Lemma can_emit_sub_projection
  {validator : Type}
  (A : validator -> index)
  (sender : message -> option validator)
  (Hsender_safety : sender_safety_alt_prop IM A sender)
  (j : index)
  (m : message)
  (Hj : option_map A (sender m) = Some j)
  : can_emit PreSubFree m -> can_emit (pre_loaded_with_all_messages_vlsm (IM j)) m.
Proof.
  intro Hemit.
  apply can_emit_projection with validator A sender; [assumption|assumption|].
  revert Hemit.
  apply (VLSM_full_projection_can_emit lift_sub_preloaded_free_full_projection).
Qed.

(** If a node can emit a message, it can also emit it in a subcomposition with
other nodes, and starting with more pre-loaded messages.
*)
Lemma can_emit_with_more
  (j : index)
  (m : message)
  (Hj : j ∈ indices)
  (P Q : message -> Prop)
  (PimpliesQ : forall m, P m -> Q m)
  : can_emit (pre_loaded_vlsm (IM j) P) m -> can_emit (pre_loaded_vlsm SubFree Q) m.
Proof.
  intro Hemit.
  specialize
    (lift_to_composite_generalized_preloaded_vlsm_full_projection
      (sub_IM IM indices) _ _ PimpliesQ (dexist j Hj))
    as Hproj.
  apply (VLSM_full_projection_can_emit Hproj).
  assumption.
Qed.

End sub_composition_preloaded_lift.

Section empty_sub_composition.

(** ** A subcomposition with no components

If taking the subset of indices used for the sub-composition to be the empty
set of indices, the obtained sub-composition is an empty composition.
*)

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  indices
  (sub_IM := sub_IM IM indices)
  (sub_index_prop_dec : forall i, Decision (sub_index_prop indices i) := sub_index_prop_dec indices)
  (Hno_indices : indices = [])
  .

(** If a sub-composition [can_emit] a message then its sender must be one of
the components of the sub-composition.
*)
Lemma sub_no_indices_no_can_emit (P : message -> Prop)
  : forall m, ~ can_emit (pre_loaded_vlsm (free_composite_vlsm sub_IM) P) m.
Proof.
  apply
    (pre_loaded_empty_composition_no_emit sub_IM (free_constraint sub_IM) []).
  - constructor.
    + constructor.
    + intro sub_i. destruct_dec_sig sub_i i Hi Heqsub_i.
      subst indices. inversion Hi.
  - reflexivity.
Qed.

End empty_sub_composition.

Section update_IM.

Context
  {message : Type}
  `{EqDecision index}
  (IM : index -> VLSM message)
  (selection : set index)
  .

Definition update_IM
  (replacement_IM : sub_index selection -> VLSM message)
  (i : index)
  : VLSM message :=
  match decide (i ∈ selection) with
  | left i_in => replacement_IM (dec_exist (sub_index_prop selection) i i_in)
  | _ => IM i
  end.
(* TODO(bmmoore): use the definition above to provide an alternate definition
for fixed-set equivocation model, similar to the one for byzantine traces.
*)

Context
  (replacement_IM : sub_index selection -> VLSM message)
  (updated_IM := update_IM replacement_IM)
  `{finite.Finite index}
  (selection_complement : set index := set_diff (enum index) selection)
  .

Lemma update_IM_complement_Hbs
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  : forall sub_i : sub_index selection_complement,
    HasBeenSentCapability (sub_IM updated_IM selection_complement sub_i).
Proof.
  intros sub_i.
  unfold sub_IM, updated_IM, update_IM.
  case_decide; [|apply Hbs].
  exfalso.
  destruct_dec_sig sub_i i Hi Heqsub_i.
  subst. simpl in H0.
  apply set_diff_elim2 in Hi.
  contradiction.
Qed.

End update_IM.
