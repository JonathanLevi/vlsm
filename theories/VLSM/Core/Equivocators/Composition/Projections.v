From stdpp Require Import prelude.
From Coq Require Import FinFun FunctionalExtensionality Program.
From VLSM Require Import Lib.Preamble Lib.ListExtras Lib.StdppListSet Lib.FinExtras.
From VLSM Require Import Core.VLSM Core.VLSMProjections Core.Composition Core.ProjectionTraces.
From VLSM Require Import Core.SubProjectionTraces Core.Equivocation Core.Equivocation.NoEquivocation.
From VLSM Require Import Core.Equivocators.Common Core.Equivocators.Projections.
From VLSM Require Import Core.Equivocators.MessageProperties.
From VLSM Require Import Core.Equivocators.Composition.Common.

(** * VLSM Equivocator Composition Projections *)

Section equivocators_composition_projections.

Context {message : Type}
  {equiv_index : Type}
  (index := equiv_index)
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (equivocator_descriptors := equivocator_descriptors IM)
  (equivocators_no_equivocations_vlsm := equivocators_no_equivocations_vlsm IM Hbs)
  (equivocators_state_project := equivocators_state_project IM)
  (equivocator_IM := equivocator_IM IM)
  (equivocator_descriptors_update := equivocator_descriptors_update IM)
  (proper_equivocator_descriptors := proper_equivocator_descriptors IM)
  (FreeE := free_composite_vlsm equivocator_IM)
  (PreFreeE := pre_loaded_with_all_messages_vlsm FreeE)
  (equivocators_free_Hbs : HasBeenSentCapability FreeE := free_composite_HasBeenSentCapability equivocator_IM finite_index (equivocator_Hbs IM Hbs))
  (Free := free_composite_vlsm IM)
  (PreFree := pre_loaded_with_all_messages_vlsm Free)
  .

Existing Instance equivocators_free_Hbs.

(** Given a [transition_item] <<item>> in the compositions of equivocators
of components [IM] and an [equivocator_descriptors], if the descriptors
are all valid in the destination of the transition this returns a
set of updated descriptors for corresponding positions in the origin state
of the transition, and if the transition was an in-place change to an
exisitng alternative it also returns a projected transition item in
the plain composition of [IM].
*)
Definition equivocators_transition_item_project
  (eqv_descriptors : equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  : option (option (composite_transition_item IM) * equivocator_descriptors)
  :=
  let sx := equivocators_state_project eqv_descriptors (destination item) in
  let eqv := projT1 (l item) in
  let deqv := eqv_descriptors eqv in
  match
    equivocator_vlsm_transition_item_project
      (IM eqv)
      (composite_transition_item_projection equivocator_IM item)
      deqv
      with
  | Some (Some item', deqv') =>
    Some
      (Some (@Build_transition_item message (@type message Free)
        (existT eqv (l item'))
        (input item) sx (output item))
      , equivocator_descriptors_update eqv_descriptors eqv deqv')
  | Some (None, deqv') => Some (None, equivocator_descriptors_update eqv_descriptors eqv deqv')
  | None => None
  end.

Lemma equivocators_transition_item_project_preserves_equivocating_indices
  (descriptors : equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  oitem idescriptors
  s
  (Hdescriptors : proper_equivocator_descriptors descriptors (destination item))
  (Ht : composite_transition equivocator_IM (l item) (s, input item) = (destination item, output item))
  (Hv : composite_valid equivocator_IM (l item) (s, input item))
  (Hpr : equivocators_transition_item_project descriptors item = Some (oitem, idescriptors))
  :
    (set_union (equivocating_indices IM index_listing s) (newmachine_descriptors_list IM index_listing idescriptors)) ⊆
    (set_union (equivocating_indices IM index_listing (destination item)) (newmachine_descriptors_list IM index_listing descriptors)).
Proof.

  unfold equivocators_transition_item_project
    , composite_transition_item_projection
    , composite_transition_item_projection_from_eq  in Hpr; simpl in Hpr.
  unfold eq_rect_r, eq_rect in Hpr; simpl in Hpr.
  match type of Hpr with
    (match ?exp with _ => _ end = _)
    => destruct exp as [(oitemx, deqv')|] eqn:Hitem_pr;[|congruence]
  end.
  simpl in Ht.
  destruct item. simpl in *. destruct l as (i, li). simpl in *.
  destruct (vtransition (equivocator_IM i) li (s i, input))
    as (si', om') eqn:Htei.
  inversion Ht. subst. clear Ht.
  replace idescriptors with (equivocator_descriptors_update descriptors i deqv')
    by (destruct oitemx;congruence);clear oitem Hpr.

  intros eqv Heqv. apply set_union_iff in Heqv. apply set_union_iff.
  destruct (decide (eqv = i)).
  - subst i.
    unfold equivocating_indices in *.
    unfold newmachine_descriptors_list in *.
    rewrite! elem_of_list_filter in *.
    rewrite state_update_eq.
    specialize (Hdescriptors eqv).
    rewrite state_update_eq in Hitem_pr, Hdescriptors.
    cut (is_equivocating_state (IM eqv) si' \/  is_newmachine_descriptor (IM eqv) (descriptors eqv)).
      by intuition.
    apply
      (equivocator_transition_item_project_preserves_equivocating_indices (IM eqv) {|
      l := li;
      input := input;
      destination := si';
      output := output |} _ Hdescriptors _ _ Hitem_pr _ Hv Htei).
    clear -Heqv.
    unfold equivocator_descriptors_update in Heqv.
    rewrite equivocator_descriptors_update_eq in Heqv.
    intuition.
  - destruct Heqv as [Heqv | Heqv].
    + left.
      apply elem_of_list_filter in Heqv.
      destruct Heqv as [Heqv Hin].
      apply elem_of_list_filter.
      split; [|assumption].
      rewrite state_update_neq by apply n.
      assumption.
    + right.
      apply elem_of_list_filter in Heqv.
      destruct Heqv as [Heqv Hin].
      apply elem_of_list_filter.
      split; [|assumption].
      unfold equivocator_descriptors_update in Heqv.
      rewrite equivocator_descriptors_update_neq in Heqv by apply n.
      assumption.
Qed.

(**
[zero_descriptor]s are preserved when projecting [transition_item]s of the
composition of equivocators.
*)
Lemma equivocators_transition_item_project_preserves_zero_descriptors
  (descriptors : equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  oitem idescriptors
  s
  (Ht : composite_transition equivocator_IM (l item) (s, input item) = (destination item, output item))
  (Hv : composite_valid equivocator_IM (l item) (s, input item))
  (Hpr : equivocators_transition_item_project descriptors item = Some (oitem, idescriptors))
  : forall i, descriptors i = Existing 0 -> idescriptors i = Existing 0.
Proof.
  intros i Hi.
  unfold equivocators_transition_item_project in Hpr.
  destruct (decide (i = projT1 (l item))).
  -  subst i. rewrite Hi in Hpr.
    specialize
      (equivocators_vlsm_transition_item_project_zero_descriptor (IM (projT1 (l item)))
        (composite_transition_item_projection equivocator_IM item)
        (s (projT1 (l item)))
      ) as Hpr_item.
    remember (composite_transition_item_projection equivocator_IM item) as pr_item.
    spec Hpr_item.
    {
      clear -Ht Heqpr_item.
      destruct item. simpl in *.
      destruct l as (i, li).
      unfold projT1 .
      match type of Ht with
      | (let (_, _) := ?t in _) = _ => destruct t as (si', om') eqn:Hti
      end.
      inversion Ht. subst. simpl.
      unfold eq_rect_r. simpl.
      rewrite state_update_eq. assumption.
    }
    spec Hpr_item.
    {
      clear -Hv Heqpr_item.
      destruct item. simpl in *.
      destruct l as (i, li).
      unfold projT1 .
      subst. simpl.
      unfold eq_rect_r. simpl. assumption.
    }
    destruct Hpr_item as [oitem' Hpr_item].
    rewrite Hpr_item in Hpr.
    destruct oitem'; inversion Hpr
    ; unfold equivocator_descriptors_update; rewrite equivocator_descriptors_update_eq; reflexivity.
  -
  destruct
    (equivocator_vlsm_transition_item_project (IM (projT1 (l item)))
      (composite_transition_item_projection equivocator_IM item)
      (descriptors (projT1 (l item))))
    eqn: Hpr'; [|congruence].
  destruct p.
  destruct o; inversion Hpr
  ; unfold equivocator_descriptors_update; rewrite equivocator_descriptors_update_neq; assumption.
Qed.

Lemma equivocators_transition_item_project_proper_descriptor
  (eqv_descriptors : equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  (i := projT1 (l item))
  (Hproper : proper_descriptor (IM i) (eqv_descriptors i) (destination item i))
  : is_Some (equivocators_transition_item_project eqv_descriptors item).
Proof.
  specialize
    (equivocator_transition_item_project_proper (IM (projT1 (l item)))
      (composite_transition_item_projection equivocator_IM item)
      (eqv_descriptors (projT1 (l item))) Hproper)
    as [itemx Hpr_item].
  unfold equivocators_transition_item_project.
  rewrite Hpr_item.
  destruct itemx. destruct o; eexists; reflexivity.
Qed.

Lemma equivocators_transition_item_project_proper
  (eqv_descriptors : equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  (Hproper : proper_equivocator_descriptors eqv_descriptors (destination item))
  : is_Some (equivocators_transition_item_project eqv_descriptors item).
Proof.
  apply equivocators_transition_item_project_proper_descriptor.
  apply Hproper.
Qed.

(**
A generalization of [no_equivocating_equivocator_transition_item_project] to
the composition of equivocators.
*)
Lemma no_equivocating_equivocators_transition_item_project
  (eqv_descriptors : equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  (i := projT1 (l item))
  (Hzero : (eqv_descriptors i) = Existing 0)
  (Hdest_i : is_singleton_state (IM i) (destination item i))
  (s : composite_state equivocator_IM)
  (Hv : composite_valid equivocator_IM (l item) (s, input item))
  (Ht : composite_transition equivocator_IM (l item) (s, input item) = (destination item, output item))
  : exists (Hex : existing_equivocator_label _ (projT2 (l item)))
    (lx : composite_label IM := existT i (existing_equivocator_label_extract _ (projT2 (l item)) Hex)),
  equivocators_transition_item_project eqv_descriptors item =
    Some (Some
      {| l := lx; input := input item; output := output item;
        destination := equivocators_state_project eqv_descriptors (destination item) |},
      eqv_descriptors).
Proof.
  specialize
    (no_equivocating_equivocator_transition_item_project (IM i)
      (composite_transition_item_projection equivocator_IM item)
      Hdest_i
      (s i)
    ) as Heqv_pr.
  destruct item, l. simpl in Ht, Hv. simpl in i. subst i.
  specialize (Heqv_pr Hv).
  spec Heqv_pr.
  { simpl. unfold eq_rect_r. simpl.
    destruct (vtransition (equivocator_IM x) v (s x, input)) eqn:Hti.
    clear -Ht Hti.
    inversion Ht. rewrite state_update_eq. subst. assumption.
  }
  destruct Heqv_pr as [Hex Heqv_pr].
  exists Hex.
  unfold equivocators_transition_item_project.
  unfold l. unfold projT1.
  rewrite Hzero.
  rewrite Heqv_pr.
  simpl.
  repeat f_equal.
  apply equivocator_descriptors_update_id.
  assumption.
Qed.

Lemma exists_equivocators_transition_item_project
  (item : composite_transition_item equivocator_IM)
  (s : composite_state equivocator_IM)
  (Hs : proper_existing_equivocator_label _ (projT2 (l item)) (s (projT1 (l item))))
  (Hv : composite_valid equivocator_IM (l item) (s, input item))
  (Ht : composite_transition equivocator_IM (l item) (s, input item) = (destination item, output item))
  : exists equivocators,
      not_equivocating_equivocator_descriptors IM equivocators (destination item)
      /\ exists (equivocators' : equivocator_descriptors)
        (lx : composite_label IM :=  existT (projT1 (l item)) (existing_equivocator_label_extract _ _ (existing_equivocator_label_forget_proper _ Hs)))
        (sx : composite_state IM := equivocators_state_project equivocators (destination item))
      ,
        proper_equivocator_descriptors equivocators' s
        /\ equivocators_transition_item_project equivocators item = Some
          (Some
            ({| l := lx; input := input item; output := output item; destination := sx|}) , equivocators').
Proof.
  specialize
    (exists_equivocator_transition_item_project
      (IM (projT1 (l item)))
      (composite_transition_item_projection equivocator_IM item)
      (s (projT1 (l item)))
      Hs
    ) as Hproject.
  spec Hproject.
  { clear -Hv.
    rewrite (sigT_eta (l item)) in Hv.
    assumption.
  }
  spec Hproject.
  { apply composite_transition_project_active in Ht; assumption. }
  destruct Hproject as [Heqv' [eqv [Heqv Hproject]]].
  exists (equivocator_descriptors_update (zero_descriptor IM) (projT1 (l item)) eqv).
  split.
  { intro i. unfold equivocator_descriptors_update. destruct (decide (i = projT1 (l item))).
    - subst. rewrite equivocator_descriptors_update_eq. assumption.
    - rewrite equivocator_descriptors_update_neq by assumption.
      simpl. rewrite equivocator_state_project_zero. eexists; reflexivity.
  }
  exists (equivocator_descriptors_update (zero_descriptor IM) (projT1 (l item)) (equivocator_label_descriptor (l (composite_transition_item_projection equivocator_IM item)))).
  split.
  { intro i. unfold equivocator_descriptors_update. destruct (decide (i = projT1 (l item))).
    - subst. rewrite equivocator_descriptors_update_eq. assumption.
    - rewrite equivocator_descriptors_update_neq by assumption.
      simpl. rewrite equivocator_state_project_zero. eexists;reflexivity.
  }
  unfold equivocators_transition_item_project.
  unfold equivocator_descriptors_update.
  rewrite equivocator_descriptors_update_eq, Hproject.
  f_equal. f_equal. apply equivocator_descriptors_update_twice.
Qed.

Lemma equivocators_transition_item_project_proper_descriptor_characterization
  (eqv_descriptors : equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  (i := projT1 (l item))
  (Hproper : proper_descriptor (IM i) (eqv_descriptors i) (destination item i))
  : exists oitem eqv_descriptors',
    equivocators_transition_item_project eqv_descriptors item = Some (oitem, eqv_descriptors')
    /\ match oitem with
      | Some itemx =>
        (exists (Hex : existing_equivocator_label _ (projT2 (l item))), existT i (existing_equivocator_label_extract _ _ Hex) = l itemx) /\
        input item = input itemx /\ output item = output itemx /\
        (equivocators_state_project eqv_descriptors (destination item) = destination itemx)
        /\ eqv_descriptors' i = (equivocator_label_descriptor (projT2 (l item)))
      | None => True
      end
    /\ forall
      (s : composite_state equivocator_IM)
      (Hv : composite_valid equivocator_IM (l item) (s, input item))
      (Ht : composite_transition equivocator_IM (l item) (s, input item) = (destination item, output item)),
      proper_descriptor (IM i) (eqv_descriptors' i) (s i) /\
      eqv_descriptors' = equivocator_descriptors_update eqv_descriptors i (eqv_descriptors' i) /\
      s = state_update equivocator_IM (destination item) i (s i) /\
      previous_state_descriptor_prop (IM i) (eqv_descriptors i) (s i) (eqv_descriptors' i) /\
      match oitem with
      | Some itemx =>
        forall (sx : composite_state IM)
          (Hsx : sx = equivocators_state_project eqv_descriptors' s),
          composite_valid IM (l itemx) (sx, input itemx) /\
          composite_transition IM (l itemx) (sx, input itemx) = (destination itemx, output itemx)
      | None =>
        equivocators_state_project eqv_descriptors (destination item) = equivocators_state_project eqv_descriptors' s
      end.
Proof.
  destruct
    (equivocator_transition_item_project_proper_characterization (IM i)
      (composite_transition_item_projection equivocator_IM item)
      (eqv_descriptors i) Hproper)
    as [oitemi [eqv_descriptorsi' [Hoitemi [Hitemx H]]]].
  subst i.
  unfold equivocators_transition_item_project.
  rewrite Hoitemi. clear Hoitemi.
  destruct item. simpl in *. destruct l as (i, li). simpl in *.
  destruct oitemi as [itemi'|]; eexists _; eexists _; (split; [reflexivity|])
  ; [| split; [exact I|]]
  ; [ destruct Hitemx as [[Hex Hli] [Hinputi [Houtputi [Hdestinationi Hdescriptori]]]]
  ; rewrite Hli; subst; split; [ repeat split|]
    |]
  ; [exists Hex; reflexivity|apply equivocator_descriptors_update_eq|..]
  ; intros
  ; match type of Ht with
    | (let (_, _) := ?t in _ ) = _ =>
      destruct t as (si', om') eqn:Ht'
    end
  ; inversion Ht; subst; clear Ht
  ; rewrite state_update_eq in H
  ; specialize (H _ Hv Ht')
  ; simpl in *
  ; destruct H as [Hproper' [Hex_new H]]
  .
  - repeat split.
    + unfold equivocator_descriptors_update. rewrite equivocator_descriptors_update_eq. assumption.
    + unfold equivocator_descriptors_update. rewrite equivocator_descriptors_update_eq. reflexivity.
    + apply functional_extensionality_dep. intro j.
      destruct (decide (j = i)).
      * subst. rewrite state_update_eq. reflexivity.
      * repeat (rewrite state_update_neq; [| assumption]). reflexivity.
    + unfold equivocator_descriptors_update.
      rewrite equivocator_descriptors_update_eq.
      assumption.
    + subst. specialize (H _ eq_refl). destruct H as [Hvx Htx].
      unfold equivocators_state_project. unfold Common.equivocators_state_project.
      unfold equivocator_descriptors_update.
      rewrite equivocator_descriptors_update_eq.
      rewrite Hli in Hvx. assumption.
    + subst. specialize (H _ eq_refl). destruct H as [Hvx Htx].
      unfold equivocators_state_project. unfold Common.equivocators_state_project.
      unfold equivocator_descriptors_update.
      rewrite equivocator_descriptors_update_eq.
      simpl in *. rewrite Hli in Htx. rewrite Htx. f_equal.
      apply functional_extensionality_dep.
      intro eqv.
      destruct (decide (eqv = i)).
      * subst. repeat rewrite state_update_eq.
        rewrite state_update_eq in Hdestinationi. symmetry. assumption.
      * repeat (rewrite state_update_neq; [|assumption]).
        rewrite equivocator_descriptors_update_neq; [|assumption].
        reflexivity.
  - repeat split.
    + unfold equivocator_descriptors_update. rewrite equivocator_descriptors_update_eq. assumption.
    + unfold equivocator_descriptors_update. rewrite equivocator_descriptors_update_eq. reflexivity.
    + apply functional_extensionality_dep. intro j.
      destruct (decide (j = i)).
      * subst. rewrite state_update_eq. reflexivity.
      * repeat (rewrite state_update_neq; [| assumption]). reflexivity.
    + unfold equivocator_descriptors_update.
      rewrite equivocator_descriptors_update_eq.
      assumption.
    + apply functional_extensionality_dep.
      intro eqv.
      unfold equivocators_state_project. unfold Common.equivocators_state_project.
      unfold equivocator_descriptors_update.
      destruct (decide (eqv = i)).
      * subst. rewrite state_update_eq. rewrite equivocator_descriptors_update_eq. assumption.
      * rewrite state_update_neq; [|assumption].
        rewrite equivocator_descriptors_update_neq; [|assumption].
        reflexivity.
Qed.

Lemma equivocators_transition_item_project_proper_characterization
  (eqv_descriptors : equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  (Hproper : proper_equivocator_descriptors eqv_descriptors (destination item))
  : exists oitem eqv_descriptors',
    equivocators_transition_item_project eqv_descriptors item = Some (oitem, eqv_descriptors')
    /\ match oitem with
      | Some itemx =>
        (exists (Hex : existing_equivocator_label _ (projT2 (l item))), existT (projT1 (l item)) (existing_equivocator_label_extract _ _ Hex) = l itemx) /\
         input item = input itemx /\ output item = output itemx /\
        (equivocators_state_project eqv_descriptors (destination item) = destination itemx)
        /\ eqv_descriptors' (projT1 (l item)) = (equivocator_label_descriptor (projT2 (l item)))
      | None => True
      end
    /\ forall
      (s : composite_state equivocator_IM)
      (Hv : composite_valid equivocator_IM (l item) (s, input item))
      (Ht : composite_transition equivocator_IM (l item) (s, input item) = (destination item, output item)),
      proper_equivocator_descriptors eqv_descriptors' s /\
      eqv_descriptors' = equivocator_descriptors_update eqv_descriptors (projT1 (l item)) (eqv_descriptors' (projT1 (l item))) /\
      s = state_update equivocator_IM (destination item) (projT1 (l item)) (s (projT1 (l item))) /\
      previous_state_descriptor_prop (IM (projT1 (l item))) (eqv_descriptors (projT1 (l item))) (s (projT1 (l item))) (eqv_descriptors' (projT1 (l item))) /\
      match oitem with
      | Some itemx =>
        forall (sx : composite_state IM)
          (Hsx : sx = equivocators_state_project eqv_descriptors' s),
          composite_valid IM (l itemx) (sx, input itemx) /\
          composite_transition IM (l itemx) (sx, input itemx) = (destination itemx, output itemx)
      | None =>
        equivocators_state_project eqv_descriptors (destination item) = equivocators_state_project eqv_descriptors' s
      end.
Proof.
  destruct
    (equivocators_transition_item_project_proper_descriptor_characterization eqv_descriptors item (Hproper (projT1 (l item))))
    as [oitem [eqv_descriptors' [Hoitem [Hitemx H]]]].
  exists oitem, eqv_descriptors'. split; [assumption|].
  split; [assumption|].
  intros.
  specialize (H s Hv Ht). clear Hv Ht Hoitem.
  destruct H as [Hproperi' [Heqv' [Hs [Hex_new H]]]].
  split; [|repeat split; assumption]. clear H.
  intro eqv.
  destruct (decide (eqv = (projT1 (l item)))).
  - subst. assumption.
  - rewrite Heqv'. rewrite Hs.
    rewrite state_update_neq; [|assumption].
    unfold proper_descriptor. unfold equivocator_descriptors_update.
    rewrite equivocator_descriptors_update_neq; [|assumption].
    apply Hproper.
Qed.

Lemma equivocators_transition_item_project_inv_characterization
  (eqv_descriptors eqv_descriptors': equivocator_descriptors)
  (item : composite_transition_item equivocator_IM)
  (itemx : composite_transition_item IM)
  (Hpr_item : equivocators_transition_item_project eqv_descriptors item = Some (Some itemx, eqv_descriptors'))
  : (exists (Hex : existing_equivocator_label _ (projT2 (l item))), existT (projT1 (l item)) (existing_equivocator_label_extract _ _ Hex) = l itemx) /\
    input item = input itemx /\ output item = output itemx /\
    equivocators_state_project eqv_descriptors (destination item) = destination itemx.
Proof.
  unfold equivocators_transition_item_project in Hpr_item.
  destruct
    (equivocator_vlsm_transition_item_project
      (IM (projT1 (l item)))
      (composite_transition_item_projection equivocator_IM item)
      (eqv_descriptors (projT1 (l item))))
    as [([itemi|], descriptori)|] eqn:Hpr_itemi
  ; [|congruence|congruence].
  inversion Hpr_item. subst. clear Hpr_item. simpl.
  repeat split.
  apply equivocator_transition_item_project_inv_characterization in Hpr_itemi
    as [[Hex Hl]].
  rewrite Hl. exists Hex. reflexivity.
Qed.

Definition equivocators_trace_project_folder
  (item : composite_transition_item equivocator_IM)
  (result: option (list (composite_transition_item IM) * equivocator_descriptors))
  : option (list (composite_transition_item IM) * equivocator_descriptors)
  :=
  match result with
  | None => None
  | Some (r, idescriptor) =>
    match equivocators_transition_item_project idescriptor item with
    | None => None
    | Some (None, odescriptor) => Some (r, odescriptor)
    | Some (Some item', odescriptor) => Some (item' :: r, odescriptor)
    end
  end.

Lemma equivocators_trace_project_fold_None
  (tr : list (composite_transition_item equivocator_IM))
  : fold_right equivocators_trace_project_folder None tr = None.
Proof.
  induction tr; [reflexivity|]. simpl. rewrite IHtr. reflexivity.
Qed.

Lemma equivocators_trace_project_folder_additive_iff
  (tr : list (composite_transition_item equivocator_IM))
  (itrX : list (composite_transition_item IM))
  (ieqv_descriptors eqv_descriptors : equivocator_descriptors)
  (trX' : list (composite_transition_item IM))
  : fold_right equivocators_trace_project_folder (Some (itrX, ieqv_descriptors)) tr
    = Some (trX', eqv_descriptors)
  <-> exists trX : list (composite_transition_item IM),
    fold_right equivocators_trace_project_folder (Some ([], ieqv_descriptors)) tr
      = Some (trX, eqv_descriptors)
    /\ trX' = trX ++ itrX.
Proof.
  revert trX' eqv_descriptors.
  induction tr; intros.
  - simpl. split; intro Htr.
    + inversion Htr. subst. exists []. split; reflexivity.
    + destruct Htr as [trX [HtrX HtrX']]. subst. inversion HtrX. reflexivity.
  - simpl.
    remember (fold_right equivocators_trace_project_folder (Some (itrX, ieqv_descriptors)) tr)
      as pr_itrX_tr.
    remember (fold_right equivocators_trace_project_folder (Some ([], ieqv_descriptors)) tr)
      as pr_tr.
    split.
    + intro Htr.
      destruct pr_itrX_tr as [(tr1,e1)|] ; [|inversion Htr].
      specialize (IHtr tr1 e1). apply proj1 in IHtr. specialize (IHtr eq_refl).
      destruct IHtr as [trX [Hpr_tr Htr1]].
      rewrite Hpr_tr in *. rewrite Htr1 in *.
      simpl in Htr. simpl.
      destruct (equivocators_transition_item_project e1 a)
        as [(oitem, eqv_descriptors'')|] eqn:Ha; [|congruence].
      destruct oitem; inversion Htr; eexists _; split; reflexivity.
    + intros [trX [Htr HtrX']].
      subst trX'.
      destruct pr_tr as [(tr1, e1)|]; [|inversion Htr].
      specialize (IHtr (tr1 ++ itrX) e1). apply proj2 in IHtr.
      spec IHtr. { eexists _.  split; reflexivity. }
      rewrite IHtr.
      simpl in *.
      destruct (equivocators_transition_item_project e1 a)
        as [(oitem, odescriptor)|] eqn:Ha
      ; [|discriminate Htr].
      destruct oitem as [item'|]; inversion Htr; reflexivity.
Qed.

Lemma equivocators_trace_project_folder_additive
  (tr : list (composite_transition_item equivocator_IM))
  (itrX trX : list (composite_transition_item IM))
  (ieqv_descriptors eqv_descriptors : equivocator_descriptors)
  (Htr : fold_right equivocators_trace_project_folder (Some ([], ieqv_descriptors)) tr
    = Some (trX, eqv_descriptors))
  : fold_right equivocators_trace_project_folder (Some (itrX, ieqv_descriptors)) tr
    = Some (trX ++ itrX, eqv_descriptors).
Proof.
  apply equivocators_trace_project_folder_additive_iff.
  exists trX. split; [assumption|reflexivity].
Qed.

(**
The projection of an [equivocators] trace is obtained by traversing the
trace from right to left guided by the descriptors produced by
[equivocators_transition_item_project] and gathering all non-empty
[transition_item]s it produces.
*)
Definition equivocators_trace_project
  (eqv_descriptors : equivocator_descriptors)
  (tr : list (composite_transition_item equivocator_IM))
  : option (list (composite_transition_item IM) * equivocator_descriptors)
  :=
  fold_right
    equivocators_trace_project_folder
    (Some ([], eqv_descriptors))
    tr.

Lemma equivocators_trace_project_app_iff
  (pre suf : list (composite_transition_item equivocator_IM))
  (ieqv_descriptors eqv_descriptors : equivocator_descriptors)
  (trX : list (composite_transition_item IM))
  : equivocators_trace_project eqv_descriptors (pre ++ suf)
    = Some (trX, ieqv_descriptors)
  <-> exists
    (preX sufX : list (composite_transition_item IM))
    (eqv_descriptors' : equivocator_descriptors),
    equivocators_trace_project eqv_descriptors suf = Some (sufX, eqv_descriptors') /\
    equivocators_trace_project eqv_descriptors' pre = Some (preX, ieqv_descriptors) /\
    trX = preX ++ sufX.
Proof.
  unfold equivocators_trace_project.
  rewrite fold_right_app.
  simpl.
  match goal with
  |- fold_right _ ?r _ = _ <-> _ => remember r as r_sufX
  end.
  destruct r_sufX as [(sufX, eqv_descriptors')|]
  ; [
    | rewrite equivocators_trace_project_fold_None; split;
      [intro contra; congruence| intros [preX [sufX [eqv_descriptors' [contra _]]]]; congruence]
    ].
  specialize (equivocators_trace_project_folder_additive_iff pre sufX eqv_descriptors' ieqv_descriptors trX)
    as Hadd.
  rewrite Hadd.
  split.
  - intros [preX [HpreX HtrX]]. exists preX, sufX, eqv_descriptors'. split; [reflexivity|].
    split; assumption.
  - intros [preX [_sufX [_eqv_descriptors' [Heq [Hpre HtrX]]]]].
    exists preX. inversion Heq. subst _sufX _eqv_descriptors'.
    split; assumption.
Qed.

(**
For every [transition_item] of the projection of a trace over the composition
of equivocators, there exists a corresponding item in the original trace
which projects to it.

*)
Lemma equivocators_trace_project_app_inv_item
  (tr : list (composite_transition_item equivocator_IM))
  (ieqv_descriptors eqv_descriptors : equivocator_descriptors)
  (preX sufX : list (composite_transition_item IM))
  (itemX : composite_transition_item IM)
  : equivocators_trace_project eqv_descriptors tr
    = Some (preX ++ [itemX] ++ sufX, ieqv_descriptors) ->
  exists
    (pre suf : list (composite_transition_item equivocator_IM))
    (item : (composite_transition_item equivocator_IM))
    (item_descriptors pre_descriptors : equivocator_descriptors),
    equivocators_trace_project eqv_descriptors suf = Some (sufX, item_descriptors) /\
    equivocators_transition_item_project item_descriptors item = Some (Some itemX, pre_descriptors) /\
    equivocators_trace_project pre_descriptors pre = Some (preX, ieqv_descriptors) /\
    tr = pre ++ [item] ++ suf.
Proof.
  generalize dependent sufX. generalize dependent eqv_descriptors.
  induction tr using rev_ind; intros eqv_descriptors sufX.
  - simpl. intro H. inversion H as [[Hnil Heq]]. destruct preX; inversion Hnil.
  - intro H. apply equivocators_trace_project_app_iff in H.
    destruct H as [trX' [xX [eqv_descriptors' [Hpr_x [Hpr_tr Heq]]]]].
    simpl in Hpr_x.
    destruct (equivocators_transition_item_project eqv_descriptors x)
      as [(ox, descriptorx)|] eqn:Hpr_x_item
    ; [|congruence].
    destruct xX as [|xX _empty].
    + destruct ox; [congruence|].
      inversion Hpr_x. subst. clear Hpr_x.
      rewrite app_nil_r in  Heq. subst trX'.
      specialize (IHtr eqv_descriptors' sufX Hpr_tr).
      destruct IHtr as [pre [suf [item [item_descriptors [pre_descriptors [Hpr_suf [Hpr_item [Hpr_pre Heqtr]]]]]]]].
      exists pre, (suf ++ [x]), item, item_descriptors, pre_descriptors.
      subst tr. rewrite !app_assoc.
      repeat split; [|assumption|assumption].
      apply equivocators_trace_project_app_iff.
      exists sufX, [], eqv_descriptors'. rewrite app_nil_r.
      repeat split; [|assumption].
      simpl. rewrite Hpr_x_item. reflexivity.
    + destruct ox; [|congruence].
      inversion Hpr_x. subst. clear Hpr_x.
      destruct_list_last sufX sufX' _xX Heq_sufX.
      * subst. rewrite app_nil_r in Heq. apply app_inj_tail in Heq.
        destruct Heq. subst.
        exists tr, [], x, eqv_descriptors, eqv_descriptors'.
        rewrite app_nil_r.
        repeat split; assumption.
      * subst. rewrite! app_assoc in Heq. apply app_inj_tail in Heq.
        rewrite <- app_assoc in Heq. destruct Heq. subst.
        specialize (IHtr eqv_descriptors' sufX' Hpr_tr).
        destruct IHtr as [pre [suf [item [item_descriptors [pre_descriptors [Hpr_suf [Hpr_item [Hpr_pre Heqtr]]]]]]]].
        exists pre, (suf ++ [x]), item, item_descriptors, pre_descriptors.
        subst tr. rewrite !app_assoc.
        repeat split; [|assumption|assumption].
        apply equivocators_trace_project_app_iff.
        exists sufX', [xX], eqv_descriptors'.
        repeat split; [|assumption].
        simpl. rewrite Hpr_x_item. reflexivity.
Qed.

(**
A corrollary of the above, reflecting a split in the projection to the original trace.
*)
Lemma equivocators_trace_project_app_inv
  (tr : list (composite_transition_item equivocator_IM))
  (ieqv_descriptors eqv_descriptors : equivocator_descriptors)
  (preX sufX : list (composite_transition_item IM))
  : equivocators_trace_project eqv_descriptors tr
    = Some (preX ++ sufX, ieqv_descriptors) ->
  exists
    (pre suf : list (composite_transition_item equivocator_IM))
    (eqv_descriptors' : equivocator_descriptors),
    equivocators_trace_project eqv_descriptors suf = Some (sufX, eqv_descriptors') /\
    equivocators_trace_project eqv_descriptors' pre = Some (preX, ieqv_descriptors) /\
    tr = pre ++ suf.
Proof.
  intro Hpr_tr.
  destruct sufX as [|itemX sufX].
  - rewrite app_nil_r in Hpr_tr.
    exists tr, [], eqv_descriptors. rewrite app_nil_r. repeat split. assumption.
  - change (itemX :: sufX) with ([itemX] ++ sufX) in Hpr_tr.
    apply equivocators_trace_project_app_inv_item in Hpr_tr.
    destruct Hpr_tr as [pre [suf [item [item_descriptors [pre_descriptors [Hpr_suf [Hpr_item [Hpr_pre Heqtr]]]]]]]].
    exists pre, ([item] ++ suf), pre_descriptors.
    subst. repeat split; [|assumption].
    apply equivocators_trace_project_app_iff.
    exists [itemX], sufX, item_descriptors.
    repeat split; [assumption|].
    simpl. rewrite Hpr_item. reflexivity.
Qed.

Lemma equivocators_trace_project_preserves_equivocating_indices
  (descriptors idescriptors : equivocator_descriptors)
  (tr : list (composite_transition_item equivocator_IM))
  (trX : list (composite_transition_item IM))
  (is s : composite_state equivocator_IM)
  (Htr : finite_valid_trace_from_to (pre_loaded_with_all_messages_vlsm (free_composite_vlsm equivocator_IM)) is s tr )
  (Hdescriptors : proper_equivocator_descriptors descriptors s)
  (Hproject_tr : equivocators_trace_project descriptors tr = Some (trX, idescriptors))
  :
    (set_union (equivocating_indices IM index_listing is) (newmachine_descriptors_list IM index_listing idescriptors)) ⊆
    (set_union (equivocating_indices IM index_listing s) (newmachine_descriptors_list IM index_listing descriptors)).
Proof.
  generalize dependent trX. generalize dependent descriptors.
  induction Htr using finite_valid_trace_from_to_rev_ind.
  - intros. inversion Hproject_tr. intros eqv Heqv. assumption.
  - set (x:={|l:=l|}).
    intros.
    apply equivocators_trace_project_app_iff in Hproject_tr.
    destruct Hproject_tr as [preX [sufX [descriptors' [Hproject_x [Hproject_tr _]]]]].
    simpl in Hproject_x.
    destruct
      (equivocators_transition_item_project descriptors x)
      as [(oitemx, _descriptors')|] eqn:Hpr_x ; [|congruence].
    assert (_descriptors' = descriptors') as -> by (destruct oitemx;injection Hproject_x;congruence).
    clear Hproject_x trX sufX.

    destruct Ht as [[_ [_ [Hv _]]] Ht].
    specialize
      (equivocators_transition_item_project_preserves_equivocating_indices descriptors x
         oitemx descriptors' s Hdescriptors Ht Hv Hpr_x) as Hx_preserves.
    specialize
      (equivocators_transition_item_project_proper_characterization descriptors x Hdescriptors)
      as Hpr_x_char.
    rewrite Hpr_x in Hpr_x_char.
    destruct Hpr_x_char as [_ [_ [[= <- <-] [_ Hchar2]]]].
    specialize (Hchar2 s Hv Ht) as [Hdescriptors' _].
    specialize (IHHtr _ Hdescriptors' _ Hproject_tr).
    revert IHHtr Hx_preserves. apply transitivity.
Qed.

(** The state and descriptors obtained after applying [equivocators_trace_project]
on a pre-loaded valid trace satisfy the [previous_state_descriptor_prop]erty.
*)
Lemma equivocators_trace_project_from_state_descriptors
  (descriptors idescriptors : equivocator_descriptors)
  (tr : list (composite_transition_item equivocator_IM))
  (trX : list (composite_transition_item IM))
  (is s : composite_state equivocator_IM)
  (Htr : finite_valid_trace_from_to (pre_loaded_with_all_messages_vlsm (free_composite_vlsm equivocator_IM)) is s tr )
  (Hdescriptors : proper_equivocator_descriptors descriptors s)
  (Hproject_tr : equivocators_trace_project descriptors tr = Some (trX, idescriptors))
  : forall eqv, previous_state_descriptor_prop (IM eqv) (descriptors eqv) (is eqv) (idescriptors eqv).
Proof.
  generalize dependent trX.
  generalize dependent descriptors.
  generalize dependent s.
  induction tr using rev_ind; intros.
  - inversion Hproject_tr. subst. destruct (idescriptors eqv); simpl; [reflexivity|lia].
  - apply finite_valid_trace_from_to_last in Htr as Heq_s.
    rewrite finite_trace_last_is_last in Heq_s. subst s.
    apply finite_valid_trace_from_to_app_split in Htr.
    destruct Htr as [Htr Hx].
    specialize (equivocators_pre_trace_cannot_decrease_state_size IM _ _ _ Htr) as His_tr.
    specialize (equivocators_pre_trace_cannot_decrease_state_size IM _ _ _ Hx) as Htr_x.
    specialize (IHtr _ Htr).
    specialize (equivocators_transition_item_project_proper_characterization descriptors x) as Hproperx.
    spec Hproperx Hdescriptors.
    destruct Hproperx as [oitem [final_descriptors' [Hprojectx [Hitemx Hproperx]]]].
    specialize (Hproperx (finite_trace_last is tr)).
    rewrite equivocators_trace_project_app_iff in Hproject_tr.
    simpl in *.
    rewrite Hprojectx in Hproject_tr.
    inversion Hx. subst tl s' x f. clear Hx Htl.
    destruct Ht as [[_ [_ [Hv _]]] Ht].
    specialize (Hproperx Hv Ht). simpl in Hproperx.
    destruct Hproperx as [Hproper' [Heq_final_descriptors' [Heq_ltr [Hex_new Hx]]]].
    specialize (IHtr _ Hproper').
    assert (Hex_new' : previous_state_descriptor_prop (IM eqv) (final_descriptors' eqv) (is eqv) (idescriptors eqv)).
    { destruct Hproject_tr as [preX [sufX [_final_descriptors' [H_final_descriptors' [Hproject_tr HtrX]]]]].
      apply IHtr with preX.
      destruct oitem; inversion H_final_descriptors'; subst; assumption.
    }

    destruct l as (i, li). simpl in *.
    destruct (decide (i = eqv)).
    + subst. spec His_tr eqv. spec Htr_x eqv.
      destruct (descriptors eqv) eqn:Hvin_desc_eqv.
      * simpl in Hex_new. rewrite Hex_new in Hex_new'. simpl in Hex_new'.
        simpl. assumption.
      * destruct (final_descriptors' eqv) eqn:Hfin_desc_eqv'.
        -- simpl in Hex_new, Hex_new'. rewrite Hex_new'. simpl.  lia.
        -- destruct (idescriptors eqv); simpl in *; lia.
    + rewrite Heq_final_descriptors' in Hex_new'.
      unfold equivocator_descriptors_update in Hex_new'.
      rewrite equivocator_descriptors_update_neq in Hex_new' by congruence.
      assumption.
Qed.

Lemma equivocators_trace_project_preserves_equivocating_indices_final
  (descriptors idescriptors : equivocator_descriptors)
  (tr : list (composite_transition_item equivocator_IM))
  (trX : list (composite_transition_item IM))
  (is s : composite_state equivocator_IM)
  (Htr : finite_valid_trace_from_to (pre_loaded_with_all_messages_vlsm (free_composite_vlsm equivocator_IM)) is s tr )
  (Hdescriptors : not_equivocating_equivocator_descriptors IM descriptors s)
  (Hproject_tr : equivocators_trace_project descriptors tr = Some (trX, idescriptors))
  :
    (set_union (equivocating_indices IM index_listing is) (newmachine_descriptors_list IM index_listing idescriptors)) ⊆
    (equivocating_indices IM index_listing s).
Proof.
  apply not_equivocating_equivocator_descriptors_proper in Hdescriptors as Hproper.
  specialize
    (equivocators_trace_project_preserves_equivocating_indices _ _ _ _ _ _
      Htr Hproper Hproject_tr
    ) as Hincl.
  intros eqv Heqv. spec Hincl eqv Heqv.
  apply set_union_iff in Hincl.
  clear Heqv.
  destruct Hincl as [|Heqv]; [assumption|].
  specialize (Hdescriptors eqv).
  apply elem_of_list_filter in Heqv.
  destruct Heqv as [Heqv Hin].
  destruct (descriptors eqv); [|contradiction].
  contradiction.
Qed.

(**
We can project a trace over the composition of equivocators in two ways:
(1) first project on a equivocator component, then project the equivocator to the original component
(2) first projects to the composition of original components, then project to one of them

The result below says that the two ways lead to the same result.
*)
Lemma equivocators_trace_project_finite_trace_projection_list_commute
  (i : index)
  (final_descriptors initial_descriptors : equivocator_descriptors)
  (eqv_initial : MachineDescriptor (IM i))
  (tr : list (composite_transition_item equivocator_IM))
  (trX : list (composite_transition_item IM))
  (trXi : list (vtransition_item (IM i)))
  (eqv_final := final_descriptors i)
  (Hproject_tr : equivocators_trace_project final_descriptors tr = Some (trX, initial_descriptors))
  (Hproject_tri :
    equivocator_vlsm_trace_project (IM i)
      (finite_trace_projection_list equivocator_IM i tr) eqv_final
    = Some (trXi, eqv_initial))
  : initial_descriptors i = eqv_initial /\
    finite_trace_projection_list IM i trX = trXi.
Proof.
  generalize dependent trXi. generalize dependent trX.
  generalize dependent final_descriptors.
  induction tr using rev_ind; intros.
  - simpl in Hproject_tr. inversion Hproject_tr. subst.
    clear Hproject_tr.
    simpl in Hproject_tri.
    inversion Hproject_tri. subst. split; reflexivity.
  - unfold equivocators_trace_project in Hproject_tr.
    rewrite fold_right_app in Hproject_tr.
    match type of Hproject_tr with
    | fold_right _ ?i _ = _ => destruct i as [(projectx,final_descriptors')|] eqn:Hproject_x
    end
    ; [|rewrite equivocators_trace_project_fold_None in Hproject_tr; inversion Hproject_tr].
    apply equivocators_trace_project_folder_additive_iff in Hproject_tr.
    destruct Hproject_tr as [trX0 [HtrX0 HtrX]].
    specialize (IHtr _ _ HtrX0).
    unfold finite_trace_projection_list in Hproject_tri.
    rewrite @pre_VLSM_projection_trace_project_app in Hproject_tri.
    apply equivocator_vlsm_trace_project_app in Hproject_tri.
    destruct Hproject_tri as [eqv_final' [trXi' [project_xi [HtrXi' [Hproject_xi HeqtrXi]]]]].
    assert (Hfinal'i : final_descriptors' i = eqv_final' /\ finite_trace_projection_list IM i projectx = project_xi).
    { clear - Hproject_x Hproject_xi.
      simpl in *.
      destruct (equivocators_transition_item_project final_descriptors x)
        as [(ox, final')|] eqn:Hpr_item_x
      ; [|congruence].
      unfold equivocators_transition_item_project in Hpr_item_x.
      destruct (decide (i = projT1 (l x))).
      - subst i.
        rewrite (composite_transition_item_projection_iff equivocator_IM x)
         in Hproject_xi.
        simpl in Hproject_xi.
        subst eqv_final.
        destruct (equivocator_vlsm_transition_item_project _ _ _)
          as [(oitem', descriptor')|] eqn:Heqpr_item_x
        ; [|discriminate Hproject_xi].
        destruct oitem' as [item'|]
        ; inversion Hproject_xi; subst descriptor' project_xi; clear Hproject_xi
        ; inversion Hpr_item_x; subst; clear Hpr_item_x
        ; inversion Hproject_x; subst; clear Hproject_x
        ; unfold equivocator_descriptors_update; rewrite equivocator_descriptors_update_eq
        ; [|split; reflexivity].
        split; [reflexivity|].
        simpl. destruct x. simpl in *. destruct l as (i, li). simpl in *.
        unfold pre_VLSM_projection_transition_item_project, composite_project_label. simpl.
        destruct (decide (i = i)); [|congruence].
        f_equal.
        replace e with (@eq_refl _ i) by (apply Eqdep_dec.UIP_dec; assumption). clear e.
        destruct item'.
        apply equivocator_transition_item_project_inv_characterization in Heqpr_item_x.
        simpl in *.
        destruct Heqpr_item_x as [Hl [Hinput [Houtput [Hdestination _]]]].
        subst.
        reflexivity.
      - rewrite (composite_transition_item_projection_neq equivocator_IM i x)
         in Hproject_xi by congruence.
        simpl in Hproject_xi.
        subst eqv_final.
        inversion Hproject_xi. subst. clear Hproject_xi.
        destruct
          (equivocator_vlsm_transition_item_project _ _ _)
          as [(oitem', descriptor')|] eqn:Heqpr_item_x
        ; [|discriminate Hpr_item_x].
        destruct oitem' as [item'|]
        ; inversion Hpr_item_x; subst; clear Hpr_item_x
        ; inversion Hproject_x; subst; clear Hproject_x
        ; unfold equivocator_descriptors_update; (rewrite equivocator_descriptors_update_neq ; [|assumption])
        ; [|split; reflexivity].
        split; [reflexivity|].
        simpl.
        rewrite (composite_transition_item_projection_neq IM i) by assumption.
        reflexivity.
    }
    destruct Hfinal'i as [Hfinal'i Hpr_xi].
    rewrite <- Hfinal'i in HtrXi'.
    specialize (IHtr _ HtrXi').
    destruct IHtr as [Heqv_initial Hpr_trXi'].
    split; [assumption|].
    subst.
    apply map_option_app.
Qed.

(**
A generalization of [equivocators_transition_item_project_preserves_zero_descriptors]
to full (valid) traces
*)
Lemma equivocators_trace_project_preserves_zero_descriptors
  (is : composite_state equivocator_IM)
  (tr : list (composite_transition_item equivocator_IM))
  (Htr : finite_valid_trace_from PreFreeE is tr)
  (descriptors : equivocator_descriptors)
  (idescriptors : equivocator_descriptors)
  (trX : list (composite_transition_item IM))
  (HtrX : equivocators_trace_project descriptors tr = Some (trX, idescriptors))
  : forall i, descriptors i = Existing 0 -> idescriptors i = Existing 0.
Proof.
  generalize dependent trX. generalize dependent descriptors.
  induction Htr using finite_valid_trace_from_rev_ind.
  - intros. inversion HtrX. subst. assumption.
  - intros.
    apply equivocators_trace_project_app_iff in HtrX.
    destruct HtrX as [preX [sufX [descriptors' [Hproject_x [Hproject_tr _]]]]].
    simpl in Hproject_x.
    destruct
      (equivocators_transition_item_project descriptors x)
      as [(oitemx, _descriptors')|] eqn:Hpr_x ; [|congruence].
    assert (_descriptors' = descriptors') as -> by (destruct oitemx;injection Hproject_x;congruence).
    clear Hproject_x trX sufX.

    destruct Hx as [[_ [_ [Hv _]]] Ht].
    specialize
      (equivocators_transition_item_project_preserves_zero_descriptors descriptors x
         oitemx descriptors' _ Ht Hv Hpr_x _ H) as Hx_preserves.
    apply (IHHtr _ _ Hproject_tr). assumption.
Qed.

Lemma preloaded_equivocators_valid_trace_from_project
  (final_descriptors : equivocator_descriptors)
  (is : composite_state equivocator_IM)
  (tr : list (composite_transition_item equivocator_IM))
  (final_state := finite_trace_last is tr)
  (Hproper : proper_equivocator_descriptors final_descriptors final_state)
  (Htr : finite_valid_trace_from PreFreeE is tr)
  : exists
    (trX : list (composite_transition_item IM))
    (initial_descriptors : equivocator_descriptors),
    equivocators_trace_project final_descriptors tr = Some (trX, initial_descriptors)
    /\ proper_equivocator_descriptors initial_descriptors is
    /\ equivocators_state_project final_descriptors (finite_trace_last is tr)
     = finite_trace_last (equivocators_state_project initial_descriptors is) trX.
Proof.
  generalize dependent final_descriptors.
  generalize dependent is.
  induction tr using rev_ind; intros.
  - exists []. simpl. exists final_descriptors. repeat split; assumption.
  - apply finite_valid_trace_from_app_iff in Htr.
    destruct Htr as [Htr Hx].
    specialize (IHtr _ Htr).
    specialize (equivocators_transition_item_project_proper_characterization final_descriptors x) as Hproperx.
    unfold final_state in Hproper.
    rewrite finite_trace_last_is_last in Hproper.
    spec Hproperx Hproper.
    destruct Hproperx as [oitem [final_descriptors' [Hprojectx [Hitemx Hproperx]]]].
    specialize (Hproperx (finite_trace_last is tr)).
    unfold equivocators_trace_project.
    rewrite fold_right_app.
    match goal with
    |- context [fold_right _ ?fld _] => remember fld as foldx
    end.
    simpl in Heqfoldx.
    rewrite Hprojectx in Heqfoldx.
    inversion Hx. subst tl s' x. clear Hx.
    destruct Ht as [[_ [_ [Hv _]]] Ht].
    specialize (Hproperx Hv Ht).
    destruct Hproperx as [Hproper' [Heq_final_descriptors' [Heq_ltr [Hex_new Hx]]]].
    specialize (IHtr _ Hproper').
    destruct IHtr as [trX' [initial_descriptors [Htr_project [Hproper_initial Hlst]]]].
    destruct oitem as [item|].
    + simpl in Hitemx. destruct Hitemx as [Hl [Hinput [Houtput [Hdestination _]]]].
      specialize (Hx _ eq_refl).
      destruct Hx as [Hvx Htx].
      exists (trX' ++ [item]), initial_descriptors. subst foldx.
      rewrite equivocators_trace_project_folder_additive with (trX := trX') (eqv_descriptors := initial_descriptors)
      ; [|assumption].
      split; [reflexivity|].
      split; [assumption|].
      rewrite !finite_trace_last_is_last. assumption.
    + exists trX', initial_descriptors. subst foldx. repeat split; [assumption|assumption|].
      rewrite finite_trace_last_is_last. simpl.
      simpl in Hx. simpl in Hlst. congruence.
Qed.

Lemma equivocators_trace_project_zero_descriptors
  (is : composite_state equivocator_IM)
  (tr : list (composite_transition_item equivocator_IM))
  (Htr : finite_valid_trace_from PreFreeE is tr)
  : exists (trX : list (composite_transition_item IM)),
    equivocators_trace_project (zero_descriptor IM) tr = Some (trX, (zero_descriptor IM)).
Proof.
  specialize
    (preloaded_equivocators_valid_trace_from_project
      (zero_descriptor IM) is tr
    ) as Hproject.
  simpl in Hproject. spec Hproject.  { apply zero_descriptor_proper. }
  spec Hproject Htr.
  destruct Hproject as [trX [initial_descriptors [Hproject _]]].
  exists trX.
  replace initial_descriptors with (zero_descriptor IM) in Hproject; [assumption|].
  apply functional_extensionality_dep. intros i. symmetry.
  apply (equivocators_trace_project_preserves_zero_descriptors _ _ Htr _ _ _ Hproject).
  reflexivity.
Qed.

Lemma preloaded_equivocators_valid_trace_project_inv
  (final_descriptors : equivocator_descriptors)
  (is : composite_state equivocator_IM)
  (tr : list (composite_transition_item equivocator_IM))
  (final_state := finite_trace_last is tr)
  (Htr : finite_valid_trace PreFreeE is tr)
  (trX : list (composite_transition_item IM))
  (initial_descriptors : equivocator_descriptors)
  (Hproject: equivocators_trace_project final_descriptors tr = Some (trX, initial_descriptors))
  (Hproper : proper_equivocator_descriptors initial_descriptors is)
  : proper_equivocator_descriptors final_descriptors final_state.
Proof.
  revert Hproject. revert trX Htr final_descriptors.
  induction tr using rev_ind; intros; [inversion Hproject; assumption|].
  destruct Htr as [Htr Hinit].
  apply finite_valid_trace_from_app_iff in Htr.
  destruct Htr as [Htr Hx].
  unfold equivocators_trace_project in Hproject.
  rewrite fold_right_app in Hproject.
  match type of Hproject with
  | fold_right _ ?f _ = _ => remember f as project_x
  end.
  simpl in Heqproject_x.
  destruct project_x as [(x', x_descriptors)|]
  ; [|rewrite equivocators_trace_project_fold_None in Hproject; congruence].
  destruct (equivocators_transition_item_project final_descriptors x) as [(oitem', ditem')|]
    eqn:Hproject_x
  ; [|congruence].
  apply (equivocators_trace_project_folder_additive_iff tr x' x_descriptors initial_descriptors trX)
  in Hproject.
  destruct Hproject as [trX' [Hproject_x' HeqtrX]].
  specialize (IHtr trX' (conj Htr Hinit) _ Hproject_x').
  inversion Hx. subst. clear Hx.
  unfold equivocators_transition_item_project in Hproject_x.
  simpl in Hproject_x.
  unfold composite_transition_item_projection in Hproject_x. simpl in Hproject_x.
  unfold composite_transition_item_projection_from_eq in Hproject_x. simpl in Hproject_x.
  unfold eq_rect_r in Hproject_x. simpl in Hproject_x.
  match type of Hproject_x with
  | context [equivocator_vlsm_transition_item_project ?X ?i ?c] => remember (equivocator_vlsm_transition_item_project X i c)  as projecti
  end.
  destruct projecti as [(oitem'', ditem'')|]; [|congruence].
  unfold equivocator_vlsm_transition_item_project in Heqprojecti.
  unfold final_state in *. clear final_state.
  rewrite finite_trace_last_is_last. simpl.
  destruct (final_descriptors (projT1 l)) as [sn| j] eqn:Hfinali.
  - inversion Heqprojecti. subst. clear Heqprojecti.
    inversion Hproject_x. subst; clear Hproject_x.
    inversion Heqproject_x. subst. clear Heqproject_x.
    intro e. specialize (IHtr e).
    destruct (decide (e = projT1 l)).
    + subst.
      unfold equivocator_descriptors_update in IHtr. rewrite equivocator_descriptors_update_eq in IHtr.
      rewrite Hfinali. assumption.
    + unfold equivocator_descriptors_update in IHtr.
      rewrite equivocator_descriptors_update_neq in IHtr
      ; [|assumption].
      destruct Ht as [Hv Ht].
      simpl in Ht. unfold vtransition in Ht. simpl in Ht.
      destruct l as (i, li).
      match type of Ht with
      | (let (_,_) := ?t in _) = _ => destruct t as (si', om')
      end.
      inversion Ht. subst. simpl in n.
      rewrite state_update_neq; [|assumption]. assumption.
  - destruct l as (i, li).
    unfold projT2 in Heqprojecti.
    unfold projT1 in Heqprojecti.
    destruct Ht as [Hv Ht].
    cbn in Ht.
    destruct (equivocator_transition _ _ _) as (si', om') eqn:Ht'.
    inversion Ht. subst om'. clear Ht.
    replace (s i) with si' in * by (subst; rewrite state_update_eq; reflexivity).
    destruct (equivocator_state_project si' j) as [si'j|] eqn:Hj; [|discriminate].
    destruct li as [ndi | idi li | idi li]
    ; destruct (decide _)
    ; inversion Heqprojecti; subst; clear Heqprojecti
    ; inversion Hproject_x; subst; clear Hproject_x
    ; inversion Heqproject_x; subst; clear Heqproject_x
    ; intro eqv; specialize (IHtr eqv)
    ; (destruct (decide (eqv = i))
      ; [subst eqv
        ; unfold equivocator_descriptors_update in IHtr; rewrite equivocator_descriptors_update_eq in IHtr
        ; simpl in *; rewrite Hfinali; rewrite state_update_eq
        ; eexists; exact Hj
        |
        unfold equivocator_descriptors_update in IHtr
        ; rewrite equivocator_descriptors_update_neq in IHtr
        ; [|assumption]
        ; rewrite state_update_neq; [|assumption]
        ; assumption
        ]
      ).
Qed.

(**
A corrollary of [preloaded_equivocators_valid_trace_from_project] selecting
only the [proper_equivocator_descriptors] property.
*)
Lemma preloaded_equivocators_valid_trace_project_proper_initial
  (is : composite_state equivocator_IM)
  (tr : list (composite_transition_item equivocator_IM))
  (final_state := finite_trace_last is tr)
  (Htr : finite_valid_trace_from PreFreeE is tr)
  (final_descriptors : equivocator_descriptors)
  (trX : list (composite_transition_item IM))
  (initial_descriptors : equivocator_descriptors)
  (Hproject: equivocators_trace_project final_descriptors tr = Some (trX, initial_descriptors))
  (Hproper : proper_equivocator_descriptors final_descriptors final_state)
  : proper_equivocator_descriptors initial_descriptors is.
Proof.
  destruct
    (preloaded_equivocators_valid_trace_from_project
      final_descriptors is tr Hproper Htr
    )
    as [_trX [_initial_descriptors [_Hproject [Hiproper _]]]].
  rewrite Hproject in _Hproject.
  inversion _Hproject. subst _trX _initial_descriptors.
  assumption.
Qed.

Lemma equivocators_trace_project_output_reflecting_inv
  (is: composite_state equivocator_IM)
  (tr: list (composite_transition_item equivocator_IM))
  (Htr: finite_valid_trace_from (pre_loaded_with_all_messages_vlsm (free_composite_vlsm equivocator_IM)) is tr)
  (m : message)
  (Hbbs : Exists (field_selector output m) tr)
  : exists
    (final_descriptors initial_descriptors : equivocator_descriptors)
    (trX: list (composite_transition_item IM)),
    not_equivocating_equivocator_descriptors IM final_descriptors (finite_trace_last is tr) /\
    equivocators_trace_project final_descriptors tr = Some (trX, initial_descriptors) /\
    Exists (field_selector output m) trX.
Proof.
  apply Exists_exists in Hbbs.
  destruct Hbbs as [item [Hitem Hm]]. simpl in Hm.
  apply (finite_trace_projection_list_in  equivocator_IM) in Hitem.
  destruct item. simpl in *. destruct l as (i, li). simpl in *.
  specialize
    (preloaded_finite_valid_trace_projection equivocator_IM i _ _ Htr)
    as Htri.
  specialize
    (equivocator_vlsm_trace_project_output_reflecting_inv (IM i) _ _ Htri m) as Hex.
  spec Hex.
  { apply Exists_exists.
    eexists _. split;[exact Hitem|].
    subst. reflexivity.
  }
  destruct Hex as [eqv_final [eqv_init [Heqv_init [Heqv_final [trXi [Hprojecti Hex]]]]]].
  specialize (VLSM_projection_finite_trace_last (preloaded_component_projection equivocator_IM i) _ _ Htr)
    as Hlst.
  simpl in Hlst,Heqv_final. rewrite <- Hlst in Heqv_final. clear Hlst.
  match type of Heqv_final with
  | existing_descriptor _ _ (?l i) => remember l as final
  end.
  remember (equivocator_descriptors_update (zero_descriptor IM) i eqv_final) as final_descriptors.
  assert (Hfinal_descriptors : not_equivocating_equivocator_descriptors IM final_descriptors final).
  { intro eqv. subst final_descriptors.
    destruct (decide (eqv = i)).
    - subst i.
      unfold equivocator_descriptors_update.  rewrite equivocator_descriptors_update_eq.
      assumption.
    - unfold equivocator_descriptors_update.
      rewrite equivocator_descriptors_update_neq
      ; [|assumption].
      apply zero_descriptor_proper.
  }
  exists final_descriptors.
  subst final.
  assert (Hfinal_descriptors_proper : proper_equivocator_descriptors final_descriptors (finite_trace_last is tr)).
  { apply not_equivocating_equivocator_descriptors_proper. assumption. }
  destruct (preloaded_equivocators_valid_trace_from_project  _ _ _ Hfinal_descriptors_proper Htr)
    as [trX [initial_descriptors [Hproject_tr _]]].
  exists initial_descriptors, trX. split; [assumption|]. split; [assumption|].
  specialize
    (equivocators_trace_project_finite_trace_projection_list_commute i final_descriptors initial_descriptors
      eqv_init tr trX trXi Hproject_tr)
    as Hcommute.
  assert (Hfinali : final_descriptors i = eqv_final).
  { subst. apply equivocator_descriptors_update_eq. }
  rewrite Hfinali in Hcommute.
  spec Hcommute Hprojecti.
  destruct Hcommute as [Hiniti Hcommute].
  clear -Hex Hcommute. subst.
  apply Exists_exists in Hex. destruct Hex as [x [Hx Hm]].
  apply (finite_trace_projection_list_in_rev IM) in Hx.
  destruct Hx as [itemX [HitemX [Houtput _]]].
  apply Exists_exists. exists itemX. split; [assumption|].
  simpl in *. rewrite Houtput. assumption.
Qed.

Lemma equivocators_trace_project_output_reflecting_iff
  (is: composite_state equivocator_IM)
  (tr: list (composite_transition_item equivocator_IM))
  (Htr: finite_valid_trace_from (pre_loaded_with_all_messages_vlsm (free_composite_vlsm equivocator_IM)) is tr)
  (m : message)
  : Exists (field_selector output m) tr
  <-> exists
    (final_descriptors initial_descriptors : equivocator_descriptors)
    (trX: list (composite_transition_item IM)),
    not_equivocating_equivocator_descriptors IM final_descriptors (finite_trace_last is tr) /\
    equivocators_trace_project final_descriptors tr = Some (trX, initial_descriptors) /\
    Exists (field_selector output m) trX.
Proof.
  split; [apply equivocators_trace_project_output_reflecting_inv; assumption|].
  intros [final_descriptors [initial_descriptors [trX [Hfinal_descriptors [Hpr_tr Hex]]]]].
  apply Exists_exists in Hex.
  destruct Hex as [itemX [HitemX Hm]].
  apply elem_of_list_split in HitemX.
  destruct HitemX as [preX [sufX Heq_trX]].
  subst.
  apply equivocators_trace_project_app_inv_item in Hpr_tr.
  destruct Hpr_tr as [pre [suf [item [item_descriptors [pre_descriptors [_ [Hpr_item [_ Heqtr]]]]]]]].
  subst.
  rewrite !Exists_app. right. left. constructor.
  apply equivocators_transition_item_project_inv_characterization in Hpr_item.
  destruct Hpr_item as [_ [_ [Heqoutput _]]].
  simpl in *. congruence.
Qed.

(** Projecting a pre-loaded valid trace of the composition of equivocators
using [proper_equivocator_descriptors] one obtains a pre-loaded valid trace
of the free composition of nodes.
*)
Lemma pre_equivocators_valid_trace_project
  (is final_state : vstate equivocators_no_equivocations_vlsm)
  (tr : list (composite_transition_item equivocator_IM))
  (Htr : finite_valid_trace_init_to PreFreeE is final_state tr)
  (final_descriptors : equivocator_descriptors)
  (Hproper : proper_equivocator_descriptors final_descriptors final_state)
  : exists
    (initial_descriptors : equivocator_descriptors),
    proper_equivocator_descriptors initial_descriptors is /\
    exists
    (isX := equivocators_state_project initial_descriptors is)
    (final_stateX := equivocators_state_project final_descriptors final_state)
    (trX : list (composite_transition_item IM)),
    equivocators_trace_project final_descriptors tr = Some (trX, initial_descriptors) /\
    finite_valid_trace_init_to PreFree isX final_stateX trX.
Proof.
  generalize dependent final_descriptors.
  generalize dependent final_state.
  induction tr using rev_ind; intros.
  - apply valid_trace_get_last in Htr as Hfinal_state_eq.
    subst.
    exists final_descriptors. split; [assumption|].
    exists [].
    repeat (split; [reflexivity|]).
    cut (vinitial_state_prop (free_composite_vlsm IM) (equivocators_state_project final_descriptors is)).
    { intro Hinit. split; [|assumption]. constructor.
      apply initial_state_is_valid. assumption.
    }
    apply (equivocators_initial_state_project IM); [|assumption].
    apply Htr.
  - destruct Htr as [Htr Hinit].
    apply finite_valid_trace_from_to_app_split in Htr.
    destruct Htr as [Htr Hx].
    specialize (IHtr _ (conj Htr Hinit)).
    apply finite_valid_trace_from_to_last in Hx as Hfinal_state_eq.
    change [x] with ([] ++ [x]) in Hfinal_state_eq.
    rewrite finite_trace_last_is_last in Hfinal_state_eq.
    subst.
    destruct
      (equivocators_transition_item_project_proper_characterization _ x Hproper)
      as [oitem [final_descriptors' [Hpr_x [Hchar1 Hchar2]]]].
    specialize (equivocators_trace_project_app_iff tr [x]) as Hpr_app.
    inversion Hx. subst. clear Hx Htl.
    destruct Ht as [[_ [_ [Hvx Hcx]]]  Htx].
    specialize (Hchar2 (finite_trace_last is tr) Hvx Htx).
    simpl in *.
    destruct Hchar2 as [Hproper' [Heq_final_descriptors' [Heq_last_tr [Hex_new Hchar2]]]].
    specialize (IHtr _ Hproper').
    destruct IHtr as [initial_descriptors [Hproper_initial [trX [Hpr_tr HtrX]]]].
    exists initial_descriptors.
    split; [assumption|].
    specialize (Hpr_app initial_descriptors final_descriptors).
    destruct oitem as [item|].
    + exists (trX ++ [item]).
      destruct HtrX as [HtrX HinitX].
      repeat split; [..|assumption].
      * apply (Hpr_app (trX ++ [item])).
        exists trX, [item], final_descriptors'.
        rewrite Hpr_x.
        repeat split.
        assumption.
      * apply
          (finite_valid_trace_from_to_app PreFree
            (equivocators_state_project final_descriptors' (finite_trace_last is tr)))
        ; [assumption|].
        specialize (Hchar2 _ eq_refl).
        destruct item. destruct l0 as (ix, lix).
        destruct l as (i, li).
        simpl in *.
        destruct Hchar1 as [[Hex Heq_l] [Heq_input [Heq_output [Hpr_s Heq_descli]]]].
        inversion Heq_l. subst ix.
        simpl_existT. subst lix input output.
        destruct Hchar2 as [Hvx_pr Htx_pr].
        rewrite Hpr_s.
        apply finite_valid_trace_from_to_singleton.
        repeat split
        ; [|apply any_message_is_valid_in_preloaded|assumption|assumption].
        apply finite_valid_trace_from_to_last_pstate in HtrX. assumption.
    + exists trX. clear Hchar1. rewrite Hchar2.
      split; [|assumption].
      apply (Hpr_app trX).
      exists trX, [], final_descriptors'.
      rewrite Hpr_x.
      repeat split; [assumption|]. rewrite app_nil_r. reflexivity.
Qed.

Definition equivocators_partial_trace_project
  (final_descriptors : equivocator_descriptors)
  (str : composite_state equivocator_IM * list (composite_transition_item equivocator_IM))
  : option (composite_state IM * list (composite_transition_item IM))
  :=
  let (s, tr) := str in
  if (@decide _ (not_equivocating_equivocator_descriptors_dec IM finite_index final_descriptors (finite_trace_last s tr))) then
    match equivocators_trace_project final_descriptors tr with
    | None => None
    | Some (trX, initial_descriptors) =>
        Some (equivocators_state_project initial_descriptors s, trX)
    end
    else None.

Lemma equivocators_partial_trace_project_characterization
  (final_descriptors : equivocator_descriptors)
  (X := free_composite_vlsm equivocator_IM)
  (partial_trace_project := equivocators_partial_trace_project final_descriptors)
  sX trX sY trY
  : partial_trace_project (sX, trX) = Some (sY, trY) <->
    not_equivocating_equivocator_descriptors IM final_descriptors (finite_trace_last sX trX) /\
    exists initial_descriptors,
      equivocators_trace_project final_descriptors trX = Some (trY, initial_descriptors) /\
      equivocators_state_project initial_descriptors sX = sY.
Proof.
  unfold partial_trace_project,equivocators_partial_trace_project.
  split.
  - intros Hpr_tr.
    case_decide; [|congruence].
    destruct (equivocators_trace_project final_descriptors trX)
      as [(_trY, initial_descriptors)|] eqn:Htr_project
    ; [|congruence].
    inversion Hpr_tr. subst _trY. clear Hpr_tr.
    split; [assumption|]. exists initial_descriptors. split; reflexivity.
  - intros [Hnot_equiv [initial_descriptors [Hpr_tr Hpr_s]]].
    rewrite decide_True by assumption.
    rewrite Hpr_tr. subst. reflexivity.
Qed.

Definition destruct_equivocators_partial_trace_project
  {final_descriptors : equivocator_descriptors}
  (X := free_composite_vlsm equivocator_IM)
  (partial_trace_project := equivocators_partial_trace_project final_descriptors)
  {sX trX sY trY}
  (Hpr_tr : partial_trace_project (sX, trX) = Some (sY, trY))
  : not_equivocating_equivocator_descriptors IM final_descriptors (finite_trace_last sX trX) /\
    exists initial_descriptors,
      equivocators_trace_project final_descriptors trX = Some (trY, initial_descriptors) /\
      equivocators_state_project initial_descriptors sX = sY
  := proj1 (equivocators_partial_trace_project_characterization final_descriptors sX trX sY trY) Hpr_tr.

Definition construct_equivocators_partial_trace_project
  {final_descriptors : equivocator_descriptors}
  (X := free_composite_vlsm equivocator_IM)
  (partial_trace_project := equivocators_partial_trace_project final_descriptors)
  {sX trX sY trY}
  (H : not_equivocating_equivocator_descriptors IM final_descriptors (finite_trace_last sX trX) /\
    exists initial_descriptors,
      equivocators_trace_project final_descriptors trX = Some (trY, initial_descriptors) /\
      equivocators_state_project initial_descriptors sX = sY)
  : partial_trace_project (sX, trX) = Some (sY, trY)
  := proj2 (equivocators_partial_trace_project_characterization final_descriptors sX trX sY trY) H.

Lemma equivocators_partial_trace_project_extends_left
  (final_descriptors : equivocator_descriptors)
  (X := free_composite_vlsm equivocator_IM)
  (partial_trace_project := equivocators_partial_trace_project final_descriptors)
  : forall sX trX sY trY,
  partial_trace_project (sX, trX) = Some (sY, trY) ->
  forall s'X preX,
    finite_trace_last s'X preX = sX ->
    finite_valid_trace_from (pre_loaded_with_all_messages_vlsm X) s'X (preX ++ trX) ->
    exists s'Y preY,
      partial_trace_project (s'X, preX ++ trX) = Some (s'Y, preY ++ trY) /\
      finite_trace_last s'Y preY = sY.
Proof.
  intros s tr sX trX Hpr_tr s_pre pre Hs_lst Hpre_tr.
  destruct (destruct_equivocators_partial_trace_project Hpr_tr)
    as [Hnot_equiv [initial_descriptors [Htr_project Hs_project]]].
  apply (finite_valid_trace_from_app_iff PreFreeE) in Hpre_tr.
  destruct Hpre_tr as [Hpre Htr]. subst s sX.
  apply not_equivocating_equivocator_descriptors_proper in Hnot_equiv as Hproper.
  specialize
    (preloaded_equivocators_valid_trace_project_proper_initial _ _ Htr
      _ _ _ Htr_project Hproper
    ) as Hinitial_descriptors.
  destruct
    (preloaded_equivocators_valid_trace_from_project
      _ _ _ Hinitial_descriptors Hpre
    ) as [preX [pre_descriptors [Hpre_project [Hpre_desciptors Hs_project]]]].
  exists (equivocators_state_project pre_descriptors s_pre), preX.
  split; [|symmetry; assumption].
  apply construct_equivocators_partial_trace_project.
  split; [rewrite finite_trace_last_app; assumption|].
  exists pre_descriptors. split; [|reflexivity].
  apply equivocators_trace_project_app_iff.
  exists preX, trX, initial_descriptors. repeat split; assumption.
Qed.

(** The projection of an composite equivocator state using [zero_descriptor]s
which is guaranteed to always succeed.
*)
Definition equivocators_total_state_project := equivocators_state_project (zero_descriptor IM).

Definition equivocators_total_label_project (l : composite_label equivocator_IM) : option (composite_label IM) :=
  let (i, li) := l in
  option_map (existT i) (equivocator_label_zero_project _ li).

Definition equivocators_total_trace_project
  (tr : list (composite_transition_item equivocator_IM))
  : list (composite_transition_item IM)
  :=
  from_option fst [] (equivocators_trace_project (zero_descriptor IM) tr).

(** The projection of an composite equivocator trace using [zero_descriptor]s
which is guaranteed to always succeed.
*)
Lemma equivocators_total_trace_project_characterization
  {s tr}
  (Hpre_tr : finite_valid_trace_from PreFreeE s tr)
  : equivocators_trace_project (zero_descriptor IM) tr = Some (equivocators_total_trace_project tr, zero_descriptor IM).
Proof.
  unfold equivocators_total_trace_project.
  destruct (equivocators_trace_project_zero_descriptors _ _ Hpre_tr)
    as [_trX Hpr_tr].
  rewrite Hpr_tr.
  reflexivity.
Qed.

Lemma equivocators_total_trace_project_app
  (X := FreeE)
  (trace_project := equivocators_total_trace_project)
  : forall tr1X tr2X,
      (exists sX, finite_valid_trace_from (pre_loaded_with_all_messages_vlsm X) sX (tr1X ++ tr2X)) ->
      trace_project (tr1X ++ tr2X) = trace_project tr1X ++ trace_project tr2X.
Proof.
  intros.  destruct H as [sX Hpre_tr].
  specialize (equivocators_total_trace_project_characterization Hpre_tr) as Htr12_pr.
  apply equivocators_trace_project_app_iff in Htr12_pr.
  destruct Htr12_pr as [tr1Y [tr2Y [descriptors [Htr2_pr [Htr1_pr Htr12_eq]]]]].

  apply (finite_valid_trace_from_app_iff PreFreeE) in Hpre_tr.
  destruct Hpre_tr as [Hpre_tr1 Hpre_tr2].
  rewrite (equivocators_total_trace_project_characterization Hpre_tr2) in Htr2_pr.
  inversion Htr2_pr. subst. clear Htr2_pr.
  rewrite (equivocators_total_trace_project_characterization Hpre_tr1) in Htr1_pr.
  inversion Htr1_pr. subst. assumption.
Qed.

Lemma equivocators_total_VLSM_projection_trace_project
  {s tr}
  (Hpre_tr : finite_valid_trace_from PreFreeE s tr)
  : @pre_VLSM_projection_trace_project _ (type PreFreeE) _ equivocators_total_label_project
      equivocators_total_state_project tr = equivocators_total_trace_project tr.
Proof.
  induction tr using rev_ind; [reflexivity|].
  rewrite equivocators_total_trace_project_app by (eexists; exact Hpre_tr).
  rewrite @pre_VLSM_projection_trace_project_app.
  apply finite_valid_trace_from_app_iff in Hpre_tr as [Hpre_tr Hpre_x].
  specialize (IHtr Hpre_tr).
  rewrite IHtr.
  f_equal.
  inversion Hpre_x. subst.
  destruct Ht as [[_ [_ [Hv _]]] Ht]. destruct l as (i, [sn|ji li|ji li])
  ; unfold equivocators_total_trace_project; cbn in *
  ; unfold equivocators_transition_item_project; cbn in *
  ; rewrite !equivocator_state_project_zero.
  - inversion_clear Ht.
    rewrite decide_False; [reflexivity|].
    rewrite state_update_eq. rewrite equivocator_state_extend_lst. cbv; lia.
  - destruct (equivocator_state_project _ _) as [s_i|]; [|contradiction].
    destruct (vtransition _ _ _) as (si', _om').
    inversion_clear Ht. rewrite!state_update_eq.
    destruct ji as [|ji].
    + rewrite decide_True by reflexivity. reflexivity.
    + rewrite decide_False by congruence. reflexivity.
  - destruct (equivocator_state_project _ _) as [s_i|]; [|contradiction].
    destruct (vtransition _ _ _) as (si', _om').
    inversion_clear Ht. rewrite!state_update_eq.
    rewrite !equivocator_state_extend_lst.
    rewrite decide_False by (cbv; lia).
    destruct ji; reflexivity.
Qed.

Lemma equivocators_total_trace_project_final_state
  (X := FreeE)
  (state_project := equivocators_total_state_project)
  (trace_project := equivocators_total_trace_project)
  : forall sX trX,
      finite_valid_trace_from (pre_loaded_with_all_messages_vlsm X) sX trX ->
      state_project (finite_trace_last sX trX) = finite_trace_last (state_project sX) (trace_project trX).
Proof.
  intros sX trX Hpre_tr.
  specialize (equivocators_total_trace_project_characterization Hpre_tr) as Htr_pr.
  specialize
    (preloaded_equivocators_valid_trace_from_project (zero_descriptor IM) sX trX)
    as Hproject.
  simpl in Hproject. spec Hproject.  { apply zero_descriptor_proper. }
  spec Hproject Hpre_tr.
  destruct Hproject as [_trX [initial_descriptors [_Htr_pr [_ Hlst]]]].
  rewrite Htr_pr in _Htr_pr. inversion _Htr_pr. subst.
  assumption.
Qed.

Lemma PreFreeE_PreFree_vlsm_partial_projection
  (final_descriptors : equivocator_descriptors)
  : VLSM_partial_projection PreFreeE PreFree (equivocators_partial_trace_project final_descriptors).
Proof.
  split; [split|].
  - apply equivocators_partial_trace_project_extends_left.
  - intros s tr sX trX Hpr_tr Htr.
    destruct (destruct_equivocators_partial_trace_project Hpr_tr)
      as [Hnot_equiv [initial_descriptors [Htr_project Hs_project]]].
    apply valid_trace_add_default_last in Htr.
    apply not_equivocating_equivocator_descriptors_proper in Hnot_equiv as Hproper.
    destruct (pre_equivocators_valid_trace_project _ _ _ Htr _ Hproper)
      as [_initial_descriptors [_ [_trX [_Htr_project HtrX]]]].
    rewrite Htr_project in _Htr_project.
    inversion _Htr_project. subst.
    apply valid_trace_forget_last in HtrX. assumption.
Qed.

End equivocators_composition_projections.

Section equivocators_composition_sub_projections.

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (selection : list index)
  .

(**
A generalization of [equivocators_trace_project_finite_trace_projection_list_commute]
to projections over a set of indices.

We can project a trace over the composition of equivocators in two ways:

- first project to a subset of equivocator components, then project that to the corresponding subset of the composition of the original components

- first project to the composition of original components, then project to a subset of them

The results below (fist for a single item, then for the full trace say that the
two ways lead to the same result.
*)
Lemma equivocators_trace_project_finite_trace_sub_projection_item_commute
  (item: composite_transition_item (equivocator_IM IM))
  (final_descriptors' final_descriptors: equivocator_descriptors IM)
  (final_sub_descriptors := fun i : sub_index selection => final_descriptors (` i))
  (pr_item: list (composite_transition_item IM))
  (Hpr_item: equivocators_trace_project IM final_descriptors [item] = Some (pr_item, final_descriptors'))
  (pr_sub_item: list (composite_transition_item (sub_IM IM selection)))
  (final_sub_descriptors': equivocator_descriptors (sub_IM IM selection))
  (Hpr_sub_item: equivocators_trace_project (sub_IM IM selection) final_sub_descriptors (finite_trace_sub_projection (equivocator_IM IM) selection [item]) = Some (pr_sub_item, final_sub_descriptors'))
  : final_sub_descriptors' = (fun i : sub_index selection => final_descriptors' (` i))
  /\ finite_trace_sub_projection IM selection pr_item = pr_sub_item.
Proof.
  unfold equivocators_trace_project in Hpr_item. unfold sub_IM in *.
  simpl in *.
  destruct (equivocators_transition_item_project IM final_descriptors item)
    as [(ox, final')|] eqn:Hpr_item_x
  ; [|congruence].
  unfold equivocators_transition_item_project in Hpr_item_x.
  unfold composite_transition_item_projection in Hpr_item_x.
  remember (equivocator_vlsm_transition_item_project (IM (projT1 (l item))) (composite_transition_item_projection_from_eq (equivocator_IM IM) item (projT1 (l item)) eq_refl) (final_descriptors (projT1 (l item))))
    as pr_item_x.
  destruct pr_item_x as [(oitem', descriptor')|]; [|congruence].

  unfold composite_transition_item_projection_from_eq in Heqpr_item_x.
  unfold eq_rect_r in Heqpr_item_x.
  simpl in Heqpr_item_x.
  unfold pre_VLSM_projection_transition_item_project
    , composite_label_sub_projection_option in Hpr_sub_item.
  case_decide.
  - simpl in Hpr_sub_item.
    unfold final_sub_descriptors in *.
    unfold equivocators_transition_item_project in Hpr_sub_item.
    match type of Hpr_sub_item with
    | context [equivocator_vlsm_transition_item_project ?X ?i ?c]
      => remember (equivocator_vlsm_transition_item_project X i c) as project
    end.
    simpl in Heqproject.
    unfold
      composite_transition_item_projection,
      composite_transition_item_projection_from_eq,
      eq_rect_r,
      composite_state_sub_projection in Heqproject.
    simpl in Heqproject.
    rewrite <-  Heqpr_item_x in Heqproject. clear Heqpr_item_x.
    subst project.
    simpl in Hpr_sub_item.
    split.
    + extensionality i.
      destruct oitem' as [item'|]
      ; inversion Hpr_sub_item; subst; clear Hpr_sub_item
      ; inversion Hpr_item_x; subst; clear Hpr_item_x
      ; inversion Hpr_item; subst; clear Hpr_item
      ; simpl
      ; destruct (decide ((proj1_sig i) = projT1 (l item))).
      * rewrite equivocator_descriptors_update_eq_rew with (Heq := e).
        assert (e1 : i = (dec_exist (sub_index_prop selection) (projT1 (l item)) H)).
        { apply dec_sig_eq_iff. assumption. }
        subst i.
        rewrite equivocator_descriptors_update_eq_rew with (Heq := eq_refl).
        simpl in e. replace e with (eq_refl (projT1 (l item))); [reflexivity|].
        apply Eqdep_dec.UIP_dec. assumption.
      * rewrite! equivocator_descriptors_update_neq; [reflexivity | assumption |].
        intro contra. elim n. apply dec_sig_eq_iff in contra. assumption.
      * rewrite equivocator_descriptors_update_eq_rew with (Heq := e).
        assert (e1 : i = (dec_exist (sub_index_prop selection) (projT1 (l item)) H)).
        { apply dec_sig_eq_iff. assumption. }
        subst i.
        rewrite equivocator_descriptors_update_eq_rew with (Heq := eq_refl).
        simpl in e. replace e with (eq_refl (projT1 (l item))); [reflexivity|].
        apply Eqdep_dec.UIP_dec. assumption.
      * rewrite! equivocator_descriptors_update_neq; [reflexivity | assumption |].
        intro contra. elim n. apply dec_sig_eq_iff in contra. assumption.
    + destruct oitem' as [item'|]
      ; inversion Hpr_sub_item; subst; clear Hpr_sub_item
      ; inversion Hpr_item_x; subst; clear Hpr_item_x
      ; inversion Hpr_item; subst; clear Hpr_item
      ; simpl; [|reflexivity].
      unfold pre_VLSM_projection_transition_item_project,
        composite_label_sub_projection_option.
      simpl.
      case_decide; [|contradiction].
      f_equal. f_equal.
      unfold composite_label_sub_projection.
      apply
        (@dec_sig_sigT_eq _
          (sub_index_prop selection)
          (sub_index_prop_dec selection)
          (fun n => vlabel (IM n))
          (projT1 (l item)) (l item') (l item') H0 H
        ).
      reflexivity.
  - simpl in Hpr_sub_item. unfold final_sub_descriptors in *.
    inversion Hpr_sub_item. subst. clear Hpr_sub_item.
    split.
    + extensionality i.
      assert (Hnot : proj1_sig i <> projT1 (l item)).
      { intro Hnot. elim H. destruct i. simpl in Hnot. subst.
        apply bool_decide_spec in i. assumption.
      }
      destruct oitem' as [item'|]
      ; inversion Hpr_item_x; subst; clear Hpr_item_x
      ; inversion Hpr_item; subst; clear Hpr_item
      ; simpl
      ; rewrite equivocator_descriptors_update_neq; [reflexivity| assumption | reflexivity| assumption].
    + destruct oitem' as [item'|]
      ; inversion Hpr_item_x; subst; clear Hpr_item_x
      ; inversion Hpr_item; subst; clear Hpr_item
      ; simpl; [|reflexivity].
      unfold from_sub_projection. simpl.
      unfold pre_VLSM_projection_transition_item_project,
        composite_label_sub_projection_option.
      simpl.
      case_decide; [contradiction|].
      reflexivity.
Qed.

Lemma equivocators_trace_project_finite_trace_sub_projection_commute
  (final_descriptors initial_descriptors : equivocator_descriptors IM)
  (initial_sub_descriptors : equivocator_descriptors (sub_IM IM selection))
  (tr : list (composite_transition_item (equivocator_IM IM)))
  (trX : list (composite_transition_item IM))
  (tr_subX : list (composite_transition_item (sub_IM IM selection)))
  (final_sub_descriptors := fun i : sub_index selection => final_descriptors (proj1_sig i))
  (Hproject_tr : equivocators_trace_project IM final_descriptors tr = Some (trX, initial_descriptors))
  (Hproject_sub_tr :
    equivocators_trace_project (sub_IM IM selection) final_sub_descriptors
      (finite_trace_sub_projection (equivocator_IM IM) selection tr)
    = Some (tr_subX, initial_sub_descriptors))
  : initial_sub_descriptors = (fun i => initial_descriptors (proj1_sig i)) /\
    finite_trace_sub_projection IM selection trX = tr_subX.
Proof.
  generalize dependent tr_subX. generalize dependent trX.
  generalize dependent final_descriptors.
  induction tr using rev_ind; intros.
  - simpl in Hproject_tr. inversion Hproject_tr. subst.
    clear Hproject_tr.
    simpl in Hproject_sub_tr.
    inversion Hproject_sub_tr. subst. split; reflexivity.
  - unfold equivocators_trace_project in Hproject_tr.
    rewrite fold_right_app in Hproject_tr.
    match type of Hproject_tr with
    | fold_right _ ?i _ = _ => destruct i as [(projectx,final_descriptors')|] eqn:Hproject_x
    end
    ; [|rewrite equivocators_trace_project_fold_None in Hproject_tr; inversion Hproject_tr].
    apply equivocators_trace_project_folder_additive_iff in Hproject_tr.
    destruct Hproject_tr as [trX0 [HtrX0 HtrX]].
    specialize (IHtr _ _ HtrX0).
    rewrite finite_trace_sub_projection_app in Hproject_sub_tr.
    apply equivocators_trace_project_app_iff in Hproject_sub_tr.
    destruct Hproject_sub_tr as [tr_subX' [project_sub_x [final_sub_descriptors' [Hproject_sub_x [Htr_subX' Heqtr_subX]]]]].
    specialize
      (equivocators_trace_project_finite_trace_sub_projection_item_commute
        x _ _ _ Hproject_x _ _ Hproject_sub_x
      )
      as Hfinal_sub'.

    destruct Hfinal_sub' as [Hfinal_sub' Hpr_sub_x].
    subst final_sub_descriptors'.
    specialize (IHtr _ Htr_subX').
    destruct IHtr as [Heqv_initial Hpr_trXi'].
    split; [assumption|].
    subst.
    apply finite_trace_sub_projection_app.
Qed.

Section seeded_equivocators_valid_trace_project.

Context
  (seed : message -> Prop)
  (SeededXE := seeded_equivocators_no_equivocation_vlsm IM Hbs selection seed)
  (sub_equivocator_IM := sub_IM (equivocator_IM IM) selection)
  (SubFreeE := free_composite_vlsm sub_equivocator_IM)
  (SubPreFreeE := pre_loaded_with_all_messages_vlsm SubFreeE)
  (sub_IM := sub_IM IM selection)
  (SubFree := free_composite_vlsm sub_IM)
  (SeededX := pre_loaded_vlsm SubFree seed)
  (Hbs_sub : forall sub_i, HasBeenSentCapability (sub_IM sub_i) := sub_has_been_sent_capabilities IM selection Hbs)
  .

Lemma seeded_equivocators_initial_message
  (m : message)
  (Hem : vinitial_message_prop SeededXE m)
  : vinitial_message_prop SeededX m.
Proof.
  destruct Hem as [[eqv [emi Hem]]|Hseed].
  - left. exists eqv. exists emi. assumption.
  - right. assumption.
Qed.

Lemma seeded_no_equivocation_incl_preloaded
  : VLSM_incl SeededXE SubPreFreeE.
Proof.
  apply seeded_no_equivocation_incl_preloaded.
Qed.

Lemma seeded_equivocators_valid_trace_project
  (is : composite_state sub_equivocator_IM)
  (tr : list (composite_transition_item sub_equivocator_IM))
  (Htr : finite_valid_trace SeededXE is tr)
  (final_state := finite_trace_last is tr)
  (final_descriptors : (equivocator_descriptors sub_IM))
  (Hproper : proper_equivocator_descriptors sub_IM final_descriptors final_state)
  : exists
    (trX : list (composite_transition_item sub_IM))
    (initial_descriptors : equivocator_descriptors sub_IM)
    (isX := equivocators_state_project sub_IM initial_descriptors is)
    (final_stateX := finite_trace_last isX trX),
    proper_equivocator_descriptors sub_IM initial_descriptors is /\
    equivocators_trace_project sub_IM final_descriptors tr = Some (trX, initial_descriptors) /\
    equivocators_state_project sub_IM final_descriptors final_state = final_stateX /\
    finite_valid_trace SeededX isX trX.
Proof.
  assert (Htr_to : finite_valid_trace_init_to SeededXE is final_state tr).
  { destruct Htr as [Htr Hinit]. split; [|assumption].
    apply finite_valid_trace_from_add_last; [assumption|reflexivity].
  }
  assert (Hpre_tr_to : finite_valid_trace_init_to SubPreFreeE is final_state tr).
  { revert Htr_to. apply VLSM_incl_finite_valid_trace_init_to.
    apply seeded_no_equivocation_incl_preloaded.
  }
  apply pre_equivocators_valid_trace_project
    with (final_descriptors0 := final_descriptors)
    in Hpre_tr_to
  ; [|assumption..].
  destruct Hpre_tr_to as [initial_descriptors [Hproper_initial [trX [Hpr_trX Hpre_trX]]]].
  exists trX, initial_descriptors.
  split; [assumption|]. split; [assumption|].
  apply finite_valid_trace_init_to_last in Hpre_trX as Hfinal_stateX.
  symmetry in Hfinal_stateX.
  split; [assumption|].
  clear -SubPreFreeE Hbs_sub finite_index Htr Hproper Hpr_trX.
  remember (length tr) as len_tr.
  generalize dependent trX.
  generalize dependent initial_descriptors.
  generalize dependent final_descriptors. generalize dependent tr.
  induction len_tr using (well_founded_induction Wf_nat.lt_wf); intros.
  subst len_tr.
  destruct_list_last tr tr' lst Htr_lst.
  - clear H. subst. subst final_state. simpl in *. inversion Hpr_trX. subst.
    cut (vinitial_state_prop SubFree (equivocators_state_project sub_IM initial_descriptors is)).
    { intro. split; [|assumption]. constructor.
      apply valid_state_prop_iff. left.
      exists (exist _ _ H). reflexivity.
    }
    apply equivocators_initial_state_project; [|assumption].
    apply Htr.
  - specialize (H (length tr')) as H'.
    spec H'. { rewrite app_length. simpl. lia. }
    destruct Htr as [Htr Hinit].
    apply finite_valid_trace_from_app_iff in Htr.
    destruct Htr as [Htr Hlst].
    specialize (H' tr' (conj Htr Hinit) eq_refl).
    specialize (equivocators_transition_item_project_proper_characterization sub_IM final_descriptors lst) as Hproperx.
    unfold final_state in Hproper. rewrite Htr_lst in Hproper.
    rewrite finite_trace_last_is_last in Hproper.
    spec Hproperx Hproper.
    destruct Hproperx as [oitem [final_descriptors' [Hprojectx [Hitemx Hproperx]]]].
    specialize (Hproperx (finite_trace_last is tr')).
    apply equivocators_trace_project_app_iff in Hpr_trX.
    destruct Hpr_trX as [trX' [lstX [_final_descriptors' [_Hprojectx [Hpr_trX' Heq_trX]]]]].
    subst trX tr.
    simpl in _Hprojectx.
    replace (equivocators_transition_item_project _ _ _) with (Some (oitem, final_descriptors'))
      in _Hprojectx.
    assert (Heq_final_descriptors' : final_descriptors' = _final_descriptors')
      by (destruct oitem; inversion _Hprojectx; reflexivity).
    subst _final_descriptors'.
    inversion Hlst. subst tl s' lst.
    destruct Ht as [[Hs [Hiom [Hv Hc]]] Ht].
    specialize (Hproperx Hv Ht). clear Hv Ht.
    destruct Hproperx as [Hproper' [Heq_final_descriptors' [_ [_ Hx]]]].
    specialize (H' _ Hproper' _ _ Hpr_trX').
    destruct H' as [HtrX' HinitX].
    split; [|assumption]. apply finite_valid_trace_from_app_iff.
    split; [assumption|].
    assert
      (Hlst_trX' :
        valid_state_prop SeededX (finite_trace_last (equivocators_state_project sub_IM initial_descriptors is) trX')).
    { apply (finite_valid_trace_last_pstate SeededX) in HtrX'.
      assumption.
    }
    destruct oitem as [item|]; inversion _Hprojectx; subst lstX; clear _Hprojectx
    ; [|constructor; assumption].
    simpl in Hitemx. destruct Hitemx as [Hl [Hinput [Houtput [Hdestination _]]]].
    specialize (Hx _ eq_refl).
    destruct Hx as [Hvx Htx].
    destruct item. simpl in *. subst.
    apply finite_valid_trace_singleton.
    assert (Htr_to : finite_valid_trace_init_to SeededXE is (finite_trace_last is tr') tr').
    { split; [|assumption].
      apply finite_valid_trace_from_add_last; [assumption|reflexivity].
    }
    assert (Hpre_tr_to : finite_valid_trace_init_to SubPreFreeE is (finite_trace_last is tr') tr').
    { revert Htr_to. apply VLSM_incl_finite_valid_trace_init_to.
      apply seeded_no_equivocation_incl_preloaded.
    }
    apply pre_equivocators_valid_trace_project
      with (final_descriptors0 := final_descriptors')
      in Hpre_tr_to as Hpr_tr'
    ; [|assumption..].
    destruct Hpr_tr' as [_initial_descriptors [_ [_trX' [_Hpr_trX' Heq_final_stateX']]]].
    replace (equivocators_trace_project _ _ _) with (Some (trX', initial_descriptors))
      in _Hpr_trX'.
    inversion _Hpr_trX'. subst _initial_descriptors _trX'.
    apply finite_valid_trace_init_to_last in Heq_final_stateX'.
    simpl in *.
    rewrite <- Heq_final_stateX' in Htx, Hvx.
    repeat split; [assumption| |assumption|assumption].

    destruct input as [input|]
    ; [| apply option_valid_message_None].
    apply proj1 in Hc. simpl in Hc.
    apply or_comm in Hc.
    destruct Hc as [Hinit_input | Hno_equiv]
    ; [ apply initial_message_is_valid; apply  (seeded_equivocators_initial_message input); right; assumption
      |].
    assert
      (Hs_free : valid_state_prop SubPreFreeE (finite_trace_last is tr')).
    { apply proj1, finite_valid_trace_from_to_last_pstate in Hpre_tr_to.
      assumption.
    }
    apply
      (composite_proper_sent sub_equivocator_IM
        (finite_sub_index selection finite_index)
        (equivocator_Hbs sub_IM Hbs_sub) _ Hs_free)
        in Hno_equiv.
    specialize (Hno_equiv is tr' Hpre_tr_to).
    apply finite_valid_trace_init_to_forget_last in Hpre_tr_to as Hpre_tr.
    destruct (equivocators_trace_project_output_reflecting_inv _ _ _ (proj1 Hpre_tr) _ Hno_equiv)
      as [final_descriptors_m [initial_descriptors_m [trXm [Hfinal_descriptors_m [Hproject_trXm Hex]]]]].
    specialize (H (length tr')).
    spec H. { rewrite app_length. simpl. lia. }
    specialize (H tr' (conj Htr Hinit) eq_refl).
    assert (Hfinal_descriptors_m_proper : proper_equivocator_descriptors sub_IM final_descriptors_m (finite_trace_last is tr'))
      by (apply not_equivocating_equivocator_descriptors_proper; assumption).
    specialize (H final_descriptors_m Hfinal_descriptors_m_proper).

    apply pre_equivocators_valid_trace_project
      with (final_descriptors0 := final_descriptors_m)
      in Hpre_tr_to as Hpr_tr'
    ; [|assumption..].

    destruct Hpr_tr' as [initial_descriptors_m' [Hproper_initial_m [trXm' [Hproject_trXm' HtrXm]]]].
    specialize (H _ _ Hproject_trXm').
    simpl in *. rewrite Hproject_trXm in Hproject_trXm'.
    inversion Hproject_trXm'. subst trXm' initial_descriptors_m'. clear Hproject_trXm'.
    apply option_valid_message_Some.
    apply (valid_trace_output_is_valid _ _ _ (proj1 H) _ Hex).
Qed.

Lemma SeededXE_incl_PreFreeE
  : VLSM_incl SeededXE SubPreFreeE.
Proof.
  apply basic_VLSM_strong_incl; intro; intros; [assumption| | |assumption].
  - exact I.
  - split; [|exact I]. apply H.
Qed.

Lemma PreSeededXE_incl_PreFreeE
  : VLSM_incl (pre_loaded_with_all_messages_vlsm SeededXE) SubPreFreeE.
Proof.
  apply basic_VLSM_incl_preloaded; intro; intros; [assumption| |assumption].
  split; [|exact I]. apply H.
Qed.

Lemma SeededXE_SeededX_vlsm_partial_projection
  (final_descriptors : equivocator_descriptors sub_IM)
  : VLSM_partial_projection SeededXE SeededX (equivocators_partial_trace_project sub_IM (finite_sub_index selection finite_index) final_descriptors).
Proof.
  split; [split|].
  - intros s tr sX trX Hpr_tr s_pre pre Hs_lst Hpre_tr.
    assert
      (HPreFree_pre_tr : finite_valid_trace_from SubPreFreeE s_pre (pre ++ tr)).
    { revert Hpre_tr. apply VLSM_incl_finite_valid_trace_from.
      apply SeededXE_incl_PreFreeE.
    }
    clear Hpre_tr. revert s tr sX trX Hpr_tr s_pre pre Hs_lst HPreFree_pre_tr.
    apply equivocators_partial_trace_project_extends_left.
  - intros s tr sX trX Hpr_tr Htr.
    destruct (destruct_equivocators_partial_trace_project sub_IM (finite_sub_index selection finite_index) Hpr_tr)
      as [Hnot_equiv [initial_descriptors [Htr_project Hs_project]]].
    apply not_equivocating_equivocator_descriptors_proper in Hnot_equiv as Hproper.
    destruct (seeded_equivocators_valid_trace_project _ _ Htr _ Hproper)
      as [_trX [_initial_descriptors [_ [_Htr_project [_ HtrX]]]]].
    rewrite Htr_project in _Htr_project.
    inversion _Htr_project. subst.  assumption.
Qed.

End seeded_equivocators_valid_trace_project.

End equivocators_composition_sub_projections.

Section equivocators_composition_vlsm_projection.

Context {message : Type}
  {equiv_index : Type}
  (index := equiv_index)
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (Hbs : forall i : index, HasBeenSentCapability (IM i))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (finite_index' : finite.Finite index := Listing_finite finite_index)
  (equivocators_no_equivocations_vlsm := equivocators_no_equivocations_vlsm IM Hbs)
  (equivocators_state_project := equivocators_state_project IM)
  (equivocator_IM := equivocator_IM IM)
  (equivocator_descriptors_update := equivocator_descriptors_update IM)
  (proper_equivocator_descriptors := proper_equivocator_descriptors IM)
  (FreeE := free_composite_vlsm equivocator_IM)
  (PreFreeE := pre_loaded_with_all_messages_vlsm FreeE)
  (equivocators_free_Hbs : HasBeenSentCapability FreeE := free_composite_HasBeenSentCapability equivocator_IM finite_index (equivocator_Hbs IM Hbs))
  (Free := free_composite_vlsm IM)
  (PreFree := pre_loaded_with_all_messages_vlsm Free)
  (sub_IM := sub_IM IM (finite.enum index))
  (Hbs_sub : forall sub_i, HasBeenSentCapability (sub_IM sub_i) := sub_has_been_sent_capabilities IM (finite.enum index) Hbs)
  .

Existing Instance finite_index'.

Definition free_sub_free_equivocator_descriptors
  (descriptors : equivocator_descriptors IM)
  : equivocator_descriptors sub_IM
  := fun i => descriptors (dec_proj1_sig i).

Lemma equivocators_no_equivocations_vlsm_X_vlsm_partial_projection
  (final_descriptors : equivocator_descriptors IM)
  : VLSM_partial_projection equivocators_no_equivocations_vlsm Free (equivocators_partial_trace_project IM finite_index final_descriptors).
Proof.
  split; [split|].
  - intros s tr sX trX Hpr_tr s_pre pre Hs_lst Hpre_tr.
    assert
      (HPreFree_pre_tr : finite_valid_trace_from PreFreeE s_pre (pre ++ tr)).
    { revert Hpre_tr. apply VLSM_incl_finite_valid_trace_from.
      apply equivocators_no_equivocations_vlsm_incl_PreFree.
    }
    clear Hpre_tr.  revert s tr sX trX Hpr_tr s_pre pre Hs_lst HPreFree_pre_tr.
    apply equivocators_partial_trace_project_extends_left.
  - intros s tr sX trX Hpr_tr Htr.
    destruct (destruct_equivocators_partial_trace_project IM finite_index Hpr_tr)
      as [Hnot_equiv [initial_descriptors [Htr_project Hs_project]]].
    apply not_equivocating_equivocator_descriptors_proper in Hnot_equiv as Hproper.

    specialize (sub_composition_all_full_projection equivocator_IM (equivocators_no_equivocations_constraint IM Hbs))
      as Hproj.
    apply (VLSM_full_projection_finite_valid_trace Hproj) in Htr.
    specialize
      (false_composite_no_equivocation_vlsm_with_pre_loaded
        (SubProjectionTraces.sub_IM equivocator_IM (finite.enum index))
        (free_constraint (SubProjectionTraces.sub_IM equivocator_IM (finite.enum index)))
        (equivocator_Hbs sub_IM Hbs_sub))
      as Heq.
    assert (Htr' :
      finite_valid_trace
        (composite_vlsm
          (SubProjectionTraces.sub_IM equivocator_IM (finite.enum index))
          (no_equivocations_additional_constraint
            (SubProjectionTraces.sub_IM equivocator_IM (finite.enum index))
            (free_constraint (SubProjectionTraces.sub_IM equivocator_IM (finite.enum index)))
            (equivocator_Hbs sub_IM Hbs_sub)))
        (composite_state_sub_projection equivocator_IM (finite.enum index) s)
        (VLSM_full_projection_finite_trace_project Hproj tr)
    ).
    { revert Htr.
      apply VLSM_incl_finite_valid_trace.
      clear.
      apply constraint_subsumption_incl.
      apply preloaded_constraint_subsumption_stronger.
      apply strong_constraint_subsumption_strongest.
      intros (i, li) (s, om).
      unfold free_sub_free_constraint, lift_sub_label, free_sub_free_state, free_sub_free_index.
      unfold equivocators_no_equivocations_constraint.
      intros [Hno_equiv _].
      split; [|exact I].
      destruct om as [m|]; [|exact I].
      left. destruct Hno_equiv as [Hno_equiv | Hfalse]; [|contradiction].
      destruct Hno_equiv as [eqv Hno_equiv].
      exists (dec_exist (sub_index_prop (finite.enum index)) eqv
        (SubProjectionTraces.free_sub_free_index_obligation_1 eqv)).
      assumption.
    }
    apply (VLSM_eq_finite_valid_trace Heq) in Htr'.

    specialize
      (seeded_equivocators_valid_trace_project IM Hbs finite_index
        (finite.enum index)
        (fun m => False)
        _ _ Htr'
        (free_sub_free_equivocator_descriptors final_descriptors)
        )
      as Hproject.
   spec Hproject.
   { clear -Hproper. intro sub_i.
      destruct_dec_sig sub_i i Hi Heqsub_i. subst.
      rewrite <- (VLSM_full_projection_finite_trace_last Hproj).
      apply Hproper.
    }
    destruct Hproject  as [_trX [_initial_descriptors [_ [_Htr_project [_ HtrX]]]]].

    specialize
      (equivocators_trace_project_finite_trace_sub_projection_commute IM (finite.enum index)
        final_descriptors initial_descriptors _initial_descriptors tr trX _trX
        Htr_project)
      as Hcommute.
    spec Hcommute.
    { replace (finite_trace_sub_projection _ _ _) with (VLSM_full_projection_finite_trace_project Hproj tr)
      ; [assumption|].
      clear.
      induction tr; [reflexivity|].
      simpl.
      unfold pre_VLSM_projection_transition_item_project,
        composite_label_sub_projection_option,
        pre_VLSM_full_projection_trace_item_project.
      simpl.
      case_decide.
      - f_equal; [|assumption].
        destruct a. destruct l as (i, li).
        simpl.
        f_equal.
        unfold composite_label_sub_projection. simpl.
        unfold free_sub_free_index.
        apply
          (@dec_sig_sigT_eq _ _
            (sub_index_prop_dec (finite.enum index))
            (fun n => vlabel (Common.equivocator_IM IM n))
            i li li
          ).
        reflexivity.
      - elim H. apply finite.elem_of_enum.
    }
    destruct Hcommute as [Heq_initial Heq_trX].
    subst.
    clear -HtrX.
    specialize
      (vlsm_is_pre_loaded_with_False
        (free_composite_vlsm (SubProjectionTraces.sub_IM IM (finite.enum index))))
      as Heq.
    apply (VLSM_eq_finite_valid_trace Heq) in HtrX.
    specialize (sub_composition_all_full_projection_rev IM (free_constraint IM)) as Hproj.
    assert (HtrX' : finite_valid_trace (composite_vlsm (SubProjectionTraces.sub_IM IM (finite.enum index))
      (free_sub_free_constraint IM (free_constraint IM)))
      (Common.equivocators_state_project
        (SubProjectionTraces.sub_IM IM (finite.enum index))
        (λ i : sub_index (finite.enum index), initial_descriptors (` i))
        (composite_state_sub_projection equivocator_IM (finite.enum index) s))
      (finite_trace_sub_projection IM (finite.enum index) trX)).
    { revert HtrX.
      apply VLSM_incl_finite_valid_trace.
      apply constraint_subsumption_incl.
      intro; intros.  destruct l. destruct som. exact I.
    }
    apply (VLSM_full_projection_finite_valid_trace Hproj) in HtrX'.
    replace (free_sub_free_state _ _)
      with (Common.equivocators_state_project IM initial_descriptors s)
      in HtrX'
    ; [replace (VLSM_full_projection_finite_trace_project _ _) with trX
      in HtrX'|]
    ; [assumption| |reflexivity].
    clear.
    induction trX; [reflexivity|].
    simpl.
    unfold pre_VLSM_projection_transition_item_project,
      composite_label_sub_projection_option.
    simpl.
    case_decide.
    + simpl. f_equal; [|assumption].
      destruct a. destruct l as (i, li).
      reflexivity.
    + elim H. apply finite.elem_of_enum.
Qed.

Lemma equivocators_valid_trace_from_project
  (final_descriptors : equivocator_descriptors IM)
  (is final_state : vstate equivocators_no_equivocations_vlsm)
  (tr : list (composite_transition_item equivocator_IM))
  (Hproper : not_equivocating_equivocator_descriptors IM final_descriptors final_state)
  (Htr : finite_valid_trace_from_to equivocators_no_equivocations_vlsm is final_state tr)
  : exists
    isX final_stateX
    (trX : list (composite_transition_item IM))
    (initial_descriptors : equivocator_descriptors IM),
    isX = equivocators_state_project initial_descriptors is /\
    proper_equivocator_descriptors initial_descriptors is /\
    equivocators_trace_project IM final_descriptors tr = Some (trX, initial_descriptors) /\
    equivocators_state_project final_descriptors final_state = final_stateX /\
    finite_valid_trace_from_to Free isX final_stateX trX.
Proof.
  apply valid_trace_get_last in Htr as Hfinal_state. apply valid_trace_forget_last in Htr.
  subst final_state.
  specialize
    (VLSM_partial_projection_finite_valid_trace_from (equivocators_no_equivocations_vlsm_X_vlsm_partial_projection final_descriptors)
      is tr
    ) as Hsim.
  unfold equivocators_partial_trace_project in Hsim.
  rewrite decide_True in Hsim by assumption.
  assert (HPreFree_tr : finite_valid_trace_from PreFreeE is tr).
  { revert Htr. apply VLSM_incl_finite_valid_trace_from. apply equivocators_no_equivocations_vlsm_incl_PreFree. }
  apply not_equivocating_equivocator_descriptors_proper in Hproper.
  destruct
    (preloaded_equivocators_valid_trace_from_project _
      _ _ _ Hproper HPreFree_tr
    ) as [trX [initial_descriptors [Htr_project [Hinitial_desciptors Hfinal_project]]]].
  eexists. eexists. eexists. eexists. split; [reflexivity|]. split; [apply Hinitial_desciptors|].
  split; [apply Htr_project|]. split; [apply Hfinal_project|].
  apply valid_trace_add_default_last.
  apply Hsim; [|assumption].
  rewrite Htr_project. reflexivity.
Qed.

Lemma PreFreeE_Free_vlsm_projection_type
  : VLSM_projection_type PreFreeE _ (equivocators_total_label_project IM) (equivocators_total_state_project IM).
Proof.
  apply basic_VLSM_projection_type.
  intros l Hl s om s' om' [[_ [_ [Hv _]]] Ht].
  destruct l as [i [sn| ji li| ji li]]; cbn in Hv, Ht.
  - inversion_clear Ht. unfold equivocators_total_state_project.
    rewrite (equivocators_state_project_state_update_eqv IM).
    simpl.
    apply state_update_id. reflexivity.
  - simpl in Hl. destruct ji as [|ji]; [inversion Hl|]. clear Hl.
    destruct (equivocator_state_project _ _) as [si|]; [|contradiction].
    destruct (vtransition _ _ _) as (si', _om').
    inversion_clear Ht.  unfold equivocators_total_state_project.
    rewrite (equivocators_state_project_state_update_eqv IM).
    simpl.
    apply state_update_id. reflexivity.
  - destruct (equivocator_state_project _ _) as [si|]; [|contradiction].
    destruct (vtransition _ _ _) as (si', _om').
    inversion_clear Ht.  unfold equivocators_total_state_project.
    rewrite (equivocators_state_project_state_update_eqv IM).
    simpl.
    apply state_update_id. reflexivity.
Qed.

Lemma equivocators_no_equivocations_vlsm_X_vlsm_projection
  : VLSM_projection equivocators_no_equivocations_vlsm Free (equivocators_total_label_project IM) (equivocators_total_state_project IM).
Proof.
  constructor; [constructor; intros|].
  - apply PreFreeE_Free_vlsm_projection_type.
    revert H.
    apply VLSM_incl_finite_valid_trace_from.
    apply equivocators_no_equivocations_vlsm_incl_PreFree.
  - intros.
    assert (Hpre_tr : finite_valid_trace PreFreeE sX trX).
    { revert H. apply VLSM_incl_finite_valid_trace.
      apply equivocators_no_equivocations_vlsm_incl_PreFree.
    }
    specialize
     (VLSM_partial_projection_finite_valid_trace (equivocators_no_equivocations_vlsm_X_vlsm_partial_projection (zero_descriptor IM))
       sX trX (equivocators_total_state_project IM sX) (equivocators_total_trace_project IM trX)
     ) as Hsim.
    spec Hsim.
    { simpl. rewrite decide_True by apply zero_descriptor_not_equivocating.
      rewrite (equivocators_total_trace_project_characterization IM (proj1 Hpre_tr)).
      reflexivity.
    }
    apply Hsim in H.
    remember (pre_VLSM_projection_trace_project _ _ _ _ _) as tr.
    replace tr with (equivocators_total_trace_project IM trX); [assumption|].
    subst. symmetry.
    apply (equivocators_total_VLSM_projection_trace_project IM (proj1 Hpre_tr)).
Qed.

Lemma preloaded_equivocators_no_equivocations_vlsm_X_vlsm_projection
  : VLSM_projection PreFreeE PreFree (equivocators_total_label_project IM) (equivocators_total_state_project IM).
Proof.
  constructor; [constructor; intros|].
  - apply PreFreeE_Free_vlsm_projection_type.
    assumption.
  - intros.
    specialize
     (VLSM_partial_projection_finite_valid_trace (PreFreeE_PreFree_vlsm_partial_projection IM Hbs finite_index (zero_descriptor IM))
       sX trX (equivocators_total_state_project IM sX) (equivocators_total_trace_project IM trX)
     ) as Hsim.
    spec Hsim.
    { simpl. rewrite decide_True by apply zero_descriptor_not_equivocating.
      rewrite (equivocators_total_trace_project_characterization IM (proj1 H)).
      reflexivity.
    }
    apply Hsim in H as Hpr.
    remember (pre_VLSM_projection_trace_project _ _ _ _ _) as tr.
    replace tr with (equivocators_total_trace_project IM trX); [assumption|].
    subst. symmetry.
    apply (equivocators_total_VLSM_projection_trace_project IM (proj1 H)).
Qed.

End equivocators_composition_vlsm_projection.
