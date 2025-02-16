From stdpp Require Import prelude.
From Coq Require Import Streams FinFun Rdefinitions Program.Tactics.
From VLSM Require Import Lib.Preamble Lib.ListExtras Lib.StdppListSet.
From VLSM Require Import Lib.ListSetExtras Lib.Measurable.
From VLSM Require Import Core.Decisions Core.VLSM Core.VLSMProjections.
From VLSM Require Import Core.Composition Core.ProjectionTraces.

(** * VLSM Equivocation Definitions **)

(**
 This module is dedicated to building the vocabulary for discussing equivocation.
 Equivocation occurs on the receipt of a message which has not been previously sent.
 The designated sender (validator) of the message is then said to be equivocating.
 Our main purpose is to keep track of equivocating senders in a composite context
 and limit equivocation by means of a composition constraint.
**)

Lemma exists_proj1_sig {A:Type} (P:A -> Prop) (a:A):
  (exists xP:{x | P x}, proj1_sig xP = a) <-> P a.
Proof.
  split.
  - intros [[x Hx] Heq];simpl in Heq;subst x.
    assumption.
  - intro Ha.
    exists (exist _ a Ha).
    reflexivity.
Qed.

(** ** Basic equivocation **)

Class ReachableThreshold V `{Hm : Measurable V} :=
  { threshold : {r | (r >= 0)%R}
  ; reachable_threshold : exists (vs:list V), NoDup vs /\ (sum_weights vs > proj1_sig threshold)%R
  }.

(** Assuming a set of <<state>>s, and a set of <<validator>>s,
which is [Measurable] and has a [ReachableThreshold], we can define
[BasicEquivocation] starting from a computable [is_equivocating_fn]
deciding whether a validator is equivocating in a state.

To avoid a [Finite] constraint on the entire set of validators, we will
assume that there is a finite set of validators for each state, which
can be retrieved through the [state_validators] function.
This can be taken to be entire set of validators when that is finite,
or the set of senders for all messages in the state for
[state_encapsulating_messages].

This allows us to determine the [equivocating_validators] for a given
state as those equivocating in that state.

The [equivocation_fault] is determined the as the sum of weights of the
[equivocating_validators].

We call a state [not_heavy] if its corresponding [equivocation_fault]
is lower than the [threshold] set for the <<validator>>s type.
**)

Class BasicEquivocation
  (state validator : Type)
  {measurable_V : Measurable validator}
  {reachable_threshold : ReachableThreshold validator}
  :=
  { is_equivocating (s : state) (v : validator) : Prop
  ; is_equivocating_dec : RelDecision is_equivocating

    (** retrieves a set containing all possible validators for a state. **)

  ; state_validators (s : state) : set validator

  ; state_validators_nodup : forall (s : state), NoDup (state_validators s)

    (** All validators which are equivocating in a given composite state **)

  ; equivocating_validators
      (s : state)
      : list validator
      := filter (fun v => is_equivocating s v) (state_validators s)

     (** The equivocation fault sum: the sum of the weights of equivocating
     validators **)

  ; equivocation_fault
      (s : state)
      : R
      :=
      sum_weights (equivocating_validators s)

  ; not_heavy
      (s : state)
      := (equivocation_fault s <= proj1_sig threshold)%R
 }.

Lemma equivocating_validators_nodup
  `{Heqv: BasicEquivocation st validator }
  (s : st)
  : NoDup (equivocating_validators s).
Proof.
  apply NoDup_filter. apply state_validators_nodup.
Qed.

Lemma eq_equivocating_validators_equivocation_fault
  `{Heqv: BasicEquivocation st validator }
  {ValEqDec : EqDecision validator}
  : forall s1 s2,
    set_eq (equivocating_validators s1) (equivocating_validators s2) ->
    equivocation_fault s1 = equivocation_fault s2.
Proof.
  intros.
  apply
    (set_eq_nodup_sum_weight_eq
      (equivocating_validators s1)
      (equivocating_validators s2)
    )
  ;[..|assumption]
  ; apply equivocating_validators_nodup.
Qed.

Lemma incl_equivocating_validators_equivocation_fault
  `{Heqv: BasicEquivocation st validator }
  {ValEqDec : EqDecision validator}
  : forall s1 s2,
    (equivocating_validators s1) ⊆ (equivocating_validators s2) ->
    (equivocation_fault s1 <= equivocation_fault s2)%R.
Proof.
  intros.
  apply
    (sum_weights_subseteq
      (equivocating_validators s1)
      (equivocating_validators s2)
    )
  ; [..|assumption]
  ; apply equivocating_validators_nodup.
Qed.

(** *** State-message oracles and endowing states with history

    Our first step is to define some useful concepts in the context of a single VLSM.

    Apart from basic definitions of equivocation, we introduce the concept of a
    [state_message_oracle]. Such an oracle can, given a state and a message,
    decide whether the message has been sent (or received) in the history leading
    to the current state. Formally, we say that a [message] <m> [has_been_sent]
    if we're in  [state] <s> iff every valid trace which produces <s> contains <m>
    as a sent message somewhere along the way.

    The existence of such oracles, which practically imply endowing states with history,
    is necessary if we are to detect equivocation using a composition constaint, as these
    constraints act upon states, not traces.
 **)

Section Simple.
    Context
      {message : Type}
      (vlsm : VLSM message)
      (pre_vlsm := pre_loaded_with_all_messages_vlsm vlsm)
      .

(** The following property detects equivocation in a given trace for a given message. **)

    Definition equivocation_in_trace
      (msg : message)
      (tr : list (vtransition_item vlsm))
      : Prop
      :=
      exists
        (prefix : list transition_item)
        (item : transition_item)
        (suffix : list transition_item),
        tr = prefix ++ item :: suffix
        /\ input item = Some msg
        /\ ~trace_has_message (field_selector output) msg prefix.

    Instance equivocation_in_trace_dec
      {MsgEqDec : EqDecision message}
      : RelDecision equivocation_in_trace.
    Proof.
      intros msg tr.
      apply @Decision_iff with
        (List.Exists (fun d => match d with (prefix, item, _) =>
          input item = Some msg /\ ~trace_has_message (field_selector output) msg prefix
        end) (one_element_decompositions tr)).
      - rewrite Exists_exists.  split.
        + intros [((prefix, item), suffix) [Hitem Heqv]].
          exists prefix, item, suffix. apply elem_of_list_In in Hitem.
          apply in_one_element_decompositions_iff, symmetry in Hitem.
          split; assumption.
        + intros [prefix [item [suffix [Hitem Heqv]]]].
          exists ((prefix, item), suffix).
          rewrite elem_of_list_In, in_one_element_decompositions_iff.
          split; [subst; reflexivity|assumption].
      - apply Exists_dec. intros ((prefix, item), suffix).
        apply Decision_and.
        + apply option_eq_dec.
        + apply Decision_not. apply Exists_dec. intros pitem.
          apply option_eq_dec.
    Qed.

    Lemma no_equivocation_in_empty_trace m
      : ~ equivocation_in_trace m [].
    Proof.
      intros [prefix [suffix [item [Hitem _]]]].
      destruct prefix; inversion Hitem.
    Qed.

    Lemma equivocation_in_trace_prefix
      (msg : message)
      (prefix : list (vtransition_item vlsm))
      (suffix : list (vtransition_item vlsm))
      : equivocation_in_trace msg prefix -> equivocation_in_trace msg (prefix ++ suffix).
    Proof.
      intros [pre [item [suf [Heq_prefix [Hinput Hnoutput]]]]].
      exists pre, item, (suf ++ suffix).
      subst. change (pre ++ item :: suf) with (pre ++ [item] ++ suf).
      rewrite <- !app_assoc.
      repeat split; assumption.
    Qed.

    Lemma equivocation_in_trace_last_char
      (msg : message)
      (tr : list (vtransition_item vlsm))
      (item : vtransition_item vlsm)
      : equivocation_in_trace msg (tr ++ [item]) <->
        equivocation_in_trace msg tr \/
        input item = Some msg /\ ~trace_has_message (field_selector output) msg tr.
    Proof.
      split.
      - intros [prefix [item' [suffix [Heq_tr_item' [Hinput Hnoutput]]]]].
        destruct_list_last suffix suffix' _item Heq_suffix.
        + subst. apply app_inj_tail in Heq_tr_item'.
          destruct Heq_tr_item'; subst. right. split; assumption.
        + change (item' :: suffix' ++ [_item]) with (([item'] ++ suffix') ++ [_item]) in Heq_tr_item'.
          rewrite !app_assoc in Heq_tr_item'.
          apply app_inj_tail in Heq_tr_item'.
          destruct Heq_tr_item' as [Heq_tr Heq_item].
          rewrite <- !app_assoc in Heq_tr.
          left. exists prefix, item', suffix'.
          repeat split; assumption.
      - intros
          [[prefix [item' [suffix [Heq_tr [Hinput Hnoutput]]]]]
          | [Hinput Hnoutput]].
        + exists prefix, item', (suffix ++ [item]).
          repeat split; [|assumption|assumption].
          subst tr.
          change (item' :: suffix ++ [item]) with (([item'] ++ suffix) ++ [item]).
          change (item' :: suffix) with ([item'] ++ suffix).
          rewrite !app_assoc. reflexivity.
        + exists tr, item, [].
          repeat split; assumption.
    Qed.

(** We intend to give define several message oracles: [has_been_sent], [has_not_been_sent],
    [has_been_received] and [has_not_been_received]. To avoid repetition, we give
    build some generic definitions first. **)

(** General signature of a message oracle **)

    Definition state_message_oracle
      := vstate vlsm -> message -> Prop.

    Definition specialized_selected_message_exists_in_all_traces
      (X : VLSM message)
      (message_selector : message -> transition_item -> Prop)
      (s : state)
      (m : message)
      : Prop
      :=
      forall
      (start : state)
      (tr : list transition_item)
      (Htr : finite_valid_trace_init_to X start s tr),
      trace_has_message message_selector m tr.

    Definition selected_message_exists_in_all_preloaded_traces
      := specialized_selected_message_exists_in_all_traces pre_vlsm.

    Definition specialized_selected_message_exists_in_some_traces
      (X : VLSM message)
      (message_selector : message -> transition_item -> Prop)
      (s : state)
      (m : message)
      : Prop
      :=
      exists
      (start : state)
      (tr : list transition_item)
      (Htr : finite_valid_trace_init_to X start s tr),
      trace_has_message message_selector m tr.

    Definition selected_message_exists_in_some_preloaded_traces: forall
      (message_selector : message -> transition_item -> Prop)
      (s : state)
      (m : message),
        Prop
      := specialized_selected_message_exists_in_some_traces pre_vlsm.

    Definition specialized_selected_message_exists_in_no_trace
      (X : VLSM message)
      (message_selector : message -> transition_item -> Prop)
      (s : state)
      (m : message)
      : Prop
      :=
      forall
      (start : state)
      (tr : list transition_item)
      (Htr : finite_valid_trace_init_to X start s tr),
      ~trace_has_message message_selector m tr.

    Definition selected_message_exists_in_no_preloaded_trace :=
      specialized_selected_message_exists_in_no_trace pre_vlsm.

    Lemma selected_message_exists_not_some_iff_no
      (X : VLSM message)
      (message_selector : message -> transition_item -> Prop)
      (s : state)
      (m : message)
      : ~ specialized_selected_message_exists_in_some_traces X message_selector s m
        <-> specialized_selected_message_exists_in_no_trace X message_selector s m.
    Proof.
      split.
      - intro Hnot.
        intros is tr Htr Hsend.
        apply Hnot.
        exists is, tr, Htr. exact Hsend.
      - intros Hno [is [tr [Htr Hsend]]].
        exact (Hno is tr Htr Hsend).
    Qed.

    Lemma selected_message_exists_preloaded_not_some_iff_no
      (message_selector : message -> transition_item -> Prop)
      (s : state)
      (m : message)
      : ~ selected_message_exists_in_some_preloaded_traces message_selector s m
        <-> selected_message_exists_in_no_preloaded_trace message_selector s m.
    Proof.
      apply selected_message_exists_not_some_iff_no.
    Qed.

    (** Sufficient condition for 'specialized_selected_message_exists_in_some_traces'
    *)
    Lemma specialized_selected_message_exists_in_some_traces_from
      (X : VLSM message)
      (message_selector : message -> transition_item -> Prop)
      (s : state)
      (m : message)
      (start : state)
      (tr : list transition_item)
      (Htr : finite_valid_trace_from_to X start s tr)
      (Hsome : trace_has_message message_selector m tr)
      : specialized_selected_message_exists_in_some_traces X message_selector s m.
    Proof.
      assert (valid_state_prop X start) as Hstart
        by (apply valid_trace_first_pstate in Htr; assumption).
      apply valid_state_has_trace in Hstart.
      destruct Hstart as [is [tr' Htr']].
      assert (finite_valid_trace_init_to X is s (tr'++tr)).
      {
        destruct Htr'.
        split;
        [apply finite_valid_trace_from_to_app with start|];
        assumption.
      }
      exists _, _, H.
      apply Exists_app.
      right;assumption.
    Qed.

    Definition selected_messages_consistency_prop
      (message_selector : message -> transition_item -> Prop)
      (s : vstate vlsm)
      (m : message)
      : Prop
      :=
      selected_message_exists_in_some_preloaded_traces message_selector s m
      <-> selected_message_exists_in_all_preloaded_traces message_selector s m.

    Lemma selected_message_exists_in_all_traces_initial_state
      (s : vstate vlsm)
      (Hs : vinitial_state_prop vlsm s)
      (message_selector : message -> transition_item -> Prop)
      (m : message)
      : ~ selected_message_exists_in_all_preloaded_traces message_selector s m.
    Proof.
      intro Hselected.
      assert (Hps : valid_state_prop pre_vlsm s)
        by (apply initial_state_is_valid;assumption).
      assert (Htr : finite_valid_trace_init_to pre_vlsm s s []).
      { split; try assumption. constructor. assumption. }
      specialize (Hselected s [] Htr).
      unfold trace_has_message in Hselected.
      rewrite Exists_nil in Hselected.
      assumption.
      Qed.

(** Checks if all [valid_trace]s leading to a certain state contain a certain message.
    The [message_selector] argument specifices whether we're looking for received or sent
    messages.

    Notably, the [valid_trace]s over which we are iterating belong to the preloaded
    version of the target VLSM. This is because we want VLSMs to have oracles which
    are valid irrespective of the composition they take part in. As we know,
    the behaviour preloaded VLSMs includes behaviours of its projections in any
    composition. **)

    Definition all_traces_have_message_prop
      (message_selector : message -> transition_item -> Prop)
      (oracle : state_message_oracle)
      (s : state)
      (m : message)
      : Prop
      :=
      oracle s m <-> selected_message_exists_in_all_preloaded_traces message_selector s m.

    Definition no_traces_have_message_prop
      (message_selector : message -> transition_item -> Prop)
      (oracle : state_message_oracle)
      (s : state)
      (m : message)
      : Prop
      :=
      oracle s m <-> selected_message_exists_in_no_preloaded_trace message_selector s m.

    Definition has_been_sent_prop : state_message_oracle -> state -> message -> Prop
      := (all_traces_have_message_prop (field_selector output)).

    Definition has_not_been_sent_prop : state_message_oracle -> state -> message -> Prop
      := (no_traces_have_message_prop (field_selector output)).

    Definition has_been_received_prop : state_message_oracle -> state -> message -> Prop
      := (all_traces_have_message_prop (field_selector input)).

    Definition has_not_been_received_prop : state_message_oracle -> state -> message -> Prop
      := (no_traces_have_message_prop (field_selector input)).

(** Per the vocabulary of the official VLSM document, we say that VLSMs endowed
    with a [state_message_oracle] for sent messages have the [has_been_sent] capability.
    Capabilities for receiving messages are treated analogously, so we omit mentioning
    them explicitly.

    Notably, we also define the [has_not_been_sent] oracle, which decides if a message
    has definitely not been sent, on any of the traces producing a current state.

    Furthermore, we require a [sent_excluded_middle] property, which stipulates
    that any argument to the oracle should return true in exactly one of
    [has_been_sent] and [has_not_been_sent]. **)

    Class HasBeenSentCapability := {
      has_been_sent: state_message_oracle;
      has_been_sent_dec :> RelDecision has_been_sent;

      proper_sent:
        forall (s : state)
               (Hs : valid_state_prop pre_vlsm s)
               (m : message),
               (has_been_sent_prop has_been_sent s m);

      has_not_been_sent: state_message_oracle
        := fun (s : state) (m : message) => ~ has_been_sent s m;

      proper_not_sent:
        forall (s : state)
               (Hs : valid_state_prop pre_vlsm s)
               (m : message),
               has_not_been_sent_prop has_not_been_sent s m;
    }.

    (** Reverse implication for 'selected_messages_consistency_prop'
    always holds. *)
    Lemma consistency_from_valid_state_proj2
      (s : state)
      (Hs: valid_state_prop pre_vlsm s)
      (m : message)
      (selector : message -> transition_item -> Prop)
      (Hall : selected_message_exists_in_all_preloaded_traces selector s m)
      : selected_message_exists_in_some_preloaded_traces selector s m.
    Proof.
      apply valid_state_has_trace in Hs.
      destruct Hs as [is [tr Htr]].
      exists _, _, Htr.
      apply (Hall _ _ Htr).
    Qed.

    Lemma has_been_sent_consistency
      {Hbs : HasBeenSentCapability}
      (s : state)
      (Hs : valid_state_prop pre_vlsm s)
      (m : message)
      : selected_messages_consistency_prop (field_selector output) s m.
    Proof.
      split.
      - intro Hsome.
        destruct (decide (has_been_sent s m)) as [Hsm|Hsm].
        apply proper_sent in Hsm;assumption.
        apply proper_not_sent in Hsm;[|assumption].
        exfalso.
        destruct Hsome as [is [tr [Htr Hmsg]]].
        elim (Hsm _ _ Htr).
        assumption.
      - apply consistency_from_valid_state_proj2.
        assumption.
    Qed.

    Lemma can_produce_has_been_sent
      {Hbs : HasBeenSentCapability}
      (s : state)
      (m : message)
      (Hsm : can_produce pre_vlsm s m)
      : has_been_sent s m.
    Proof.
      assert (valid_state_prop pre_vlsm s).
      { apply can_produce_valid in Hsm.
        eexists; exact Hsm.
      }
      apply proper_sent; [assumption|].
      apply has_been_sent_consistency; [assumption|].
      apply non_empty_valid_trace_from_can_produce in Hsm.
      destruct Hsm as [is [tr [lst_tr [Htr [Hlst [Hs Hm]]]]]].
      destruct_list_last tr tr' _lst_tr Heqtr; [inversion Hlst|].
      rewrite last_error_is_last in Hlst.
      inversion Hlst; subst _lst_tr; clear Hlst.
      apply valid_trace_add_default_last in Htr.
      rewrite finite_trace_last_is_last, Hs in Htr.
      eexists _, _, Htr.
      apply Exists_app. right. left. assumption.
    Qed.

    (** Sufficent condition for 'proper_sent' avoiding the
    'pre_loaded_with_all_messages_vlsm'
    *)
    Lemma specialized_proper_sent
      {Hbs : HasBeenSentCapability}
      (s : state)
      (Hs : valid_state_prop vlsm s)
      (m : message)
      (Hsome : specialized_selected_message_exists_in_some_traces vlsm (field_selector output) s m)
      : has_been_sent s m.
    Proof.
      destruct Hs as [_om Hs].
      assert (Hpres : valid_state_prop pre_vlsm s).
      { exists _om. apply (pre_loaded_with_all_messages_valid_state_message_preservation vlsm). assumption. }
      apply proper_sent; [assumption|].
      specialize (has_been_sent_consistency s Hpres m) as Hcons.
      apply Hcons.
      destruct Hsome as [is [tr [Htr Hsome]]].
      exists is, tr.
      split; [|assumption].
      revert Htr.
      unfold pre_vlsm;clear.
      destruct vlsm as (T,(S,M)).
      apply VLSM_incl_finite_valid_trace_init_to.
      apply vlsm_incl_pre_loaded_with_all_messages_vlsm.
    Qed.

    (** 'proper_sent' condition specialized to regular vlsm traces
    (avoiding 'pre_loaded_with_all_messages_vlsm')
    *)
    Lemma specialized_proper_sent_rev
      {Hbs : HasBeenSentCapability}
      (s : state)
      (Hs : valid_state_prop vlsm s)
      (m : message)
      (Hsm : has_been_sent s m)
      : specialized_selected_message_exists_in_all_traces vlsm (field_selector output) s m.
    Proof.
      destruct Hs as [_om Hs].
      assert (Hpres : valid_state_prop pre_vlsm s).
      { exists _om. apply (pre_loaded_with_all_messages_valid_state_message_preservation vlsm). assumption. }
      apply proper_sent in Hsm; [|assumption].
      intros is tr Htr.
      specialize (Hsm is tr).
      spec Hsm;[|assumption].
      revert Htr.
      unfold pre_vlsm;clear.
      destruct vlsm as (T,(S,M)).
      apply VLSM_incl_finite_valid_trace_init_to.
      apply vlsm_incl_pre_loaded_with_all_messages_vlsm.
    Qed.

    Lemma has_been_sent_consistency_proper_not_sent
      (has_been_sent: state_message_oracle)
      (has_been_sent_dec: RelDecision has_been_sent)
      (s : state)
      (m : message)
      (proper_sent: has_been_sent_prop has_been_sent s m)
      (has_not_been_sent
        := fun (s : state) (m : message) => ~ has_been_sent s m)
      (Hconsistency : selected_messages_consistency_prop (field_selector output) s m)
      : has_not_been_sent_prop has_not_been_sent s m.
    Proof.
      unfold has_not_been_sent_prop.
      unfold no_traces_have_message_prop.
      unfold has_not_been_sent.
      rewrite <- selected_message_exists_preloaded_not_some_iff_no.
      apply not_iff_compat.
      apply (iff_trans proper_sent).
      symmetry;exact Hconsistency.
    Qed.


    Class HasBeenReceivedCapability := {
      has_been_received: state_message_oracle;
      has_been_received_dec :> RelDecision has_been_received;

      proper_received:
        forall (s : state)
               (Hs : valid_state_prop pre_vlsm s)
               (m : message),
               (has_been_received_prop has_been_received s m);

      has_not_been_received: state_message_oracle
        := fun (s : state) (m : message) => ~ has_been_received s m;

      proper_not_received:
        forall (s : state)
               (Hs : valid_state_prop pre_vlsm s)
               (m : message),
               has_not_been_received_prop has_not_been_received s m;
    }.

    Lemma has_been_received_consistency
      {Hbs : HasBeenReceivedCapability}
      (s : state)
      (Hs : valid_state_prop pre_vlsm s)
      (m : message)
      : selected_messages_consistency_prop (field_selector input) s m.
    Proof.
      split.
      - intro Hsome.
        destruct (decide (has_been_received s m)) as [Hsm|Hsm];
          [apply proper_received in Hsm;assumption|].
        apply proper_not_received in Hsm;[|assumption].
        destruct Hsome as [is [tr [Htr Hsome]]].
        elim (Hsm _ _ Htr).
        assumption.
      - apply consistency_from_valid_state_proj2.
        assumption.
    Qed.

    Lemma has_been_received_consistency_proper_not_received
      (has_been_received: state_message_oracle)
      (has_been_received_dec: RelDecision has_been_received)
      (s : state)
      (m : message)
      (proper_received: has_been_received_prop has_been_received s m)
      (has_not_been_received
        := fun (s : state) (m : message) => ~ has_been_received s m)
      (Hconsistency : selected_messages_consistency_prop (field_selector input) s m)
      : has_not_been_received_prop has_not_been_received s m.
    Proof.
      unfold has_not_been_received_prop.
      unfold no_traces_have_message_prop.
      unfold has_not_been_received.
      split.
      - intros Hsm is tr Htr Hsome.
        assert (Hsm' : selected_message_exists_in_some_preloaded_traces (field_selector input) s m)
          by (exists is; exists tr; exists Htr; assumption).
        apply Hconsistency in Hsm'.
        apply proper_received in Hsm'. contradiction.
      - intro Hnone. destruct (decide (has_been_received s m)) as [Hsm|Hsm];[|assumption].
        exfalso.
        apply proper_received in Hsm. apply Hconsistency in Hsm.
        destruct Hsm as [is [tr [Htr Hsm]]].
        elim (Hnone is tr Htr). assumption.
    Qed.

    Definition sent_messages
      (s : vstate vlsm)
      : Type
      :=
      sig (fun m => selected_message_exists_in_some_preloaded_traces (field_selector output) s m).

    Lemma sent_messages_proper
      (Hhbs : HasBeenSentCapability)
      (s : vstate vlsm)
      (Hs : valid_state_prop pre_vlsm s)
      (m : message)
      : has_been_sent s m <-> exists (m' : sent_messages s), proj1_sig m' = m.
    Proof.
      unfold sent_messages. rewrite exists_proj1_sig.
      specialize (proper_sent s Hs m) as Hbs.
      unfold has_been_sent_prop,all_traces_have_message_prop in Hbs.
      rewrite Hbs.
      symmetry.
      exact (has_been_sent_consistency s Hs m).
    Qed.

    Definition received_messages
      (s : vstate vlsm)
      : Type
      :=
      sig (fun m => selected_message_exists_in_some_preloaded_traces (field_selector input) s m).

    Lemma received_messages_proper
      (Hhbs : HasBeenReceivedCapability)
      (s : vstate vlsm)
      (Hs : valid_state_prop pre_vlsm s)
      (m : message)
      : has_been_received s m <-> exists (m' : received_messages s), proj1_sig m' = m.
    Proof.
      unfold received_messages. rewrite exists_proj1_sig.
      specialize (proper_received s Hs m) as Hbs.
      unfold has_been_received_prop,all_traces_have_message_prop in Hbs.
      rewrite Hbs.
      symmetry.
      exact (has_been_received_consistency s Hs m).
    Qed.

    Class ComputableSentMessages := {
      sent_messages_fn : vstate vlsm -> list message;

      sent_messages_full :
        forall (s : vstate vlsm) (Hs : valid_state_prop pre_vlsm s) (m : message),
          m ∈ (sent_messages_fn s) <-> exists (sm : sent_messages s), proj1_sig sm = m;

      sent_messages_consistency :
        forall
          (s : vstate vlsm)
          (Hs : valid_state_prop pre_vlsm s)
          (m : message),
          selected_messages_consistency_prop (field_selector output) s m
    }.

    Lemma ComputableSentMessages_initial_state_empty
      {Hrm : ComputableSentMessages}
      (s : vinitial_state vlsm)
      : sent_messages_fn (proj1_sig s) = [].
    Proof.
      assert (Hps : valid_state_prop pre_vlsm (proj1_sig s))
        by (apply initial_state_is_valid; apply proj2_sig).
      destruct s as [s Hs]. simpl in *.
      destruct (sent_messages_fn s) as [|m l] eqn:Hsm; try reflexivity.
      specialize (sent_messages_full s Hps m) as Hl. apply proj1 in Hl.
      spec Hl; try (rewrite Hsm; left; reflexivity).
      destruct Hl as [[m0 Hm] Heq]. simpl in Heq. subst m0.
      apply sent_messages_consistency in Hm; try assumption.
      exfalso. revert Hm.
      apply selected_message_exists_in_all_traces_initial_state.
      assumption.
    Qed.

    Definition ComputableSentMessages_has_been_sent
      {Hsm : ComputableSentMessages}
      (s : vstate vlsm)
      (m : message)
      : Prop
      :=
      m ∈ (sent_messages_fn s).

    Global Instance computable_sent_message_has_been_sent_dec
      {Hsm : ComputableSentMessages}
      {eq_message: EqDecision message}
      : RelDecision ComputableSentMessages_has_been_sent :=
      fun s m => decide_rel _ _ (sent_messages_fn s).

    Lemma ComputableSentMessages_has_been_sent_proper
      {Hsm : ComputableSentMessages}
      (s : state)
      (Hs : valid_state_prop pre_vlsm s)
      (m : message)
      : has_been_sent_prop ComputableSentMessages_has_been_sent s m.
    Proof.
      unfold has_been_sent_prop. unfold all_traces_have_message_prop.
      unfold ComputableSentMessages_has_been_sent.
      split.
      - intro Hin.
        apply sent_messages_full in Hin;[|assumption].
        destruct Hin as [[m0 Hm0] Hx].
        simpl in Hx. subst m0. apply (sent_messages_consistency s Hs m).
        assumption.
      - intro H.
        apply (sent_messages_consistency s Hs m) in H.
        apply sent_messages_full; try assumption.
        exists (exist _ m H). reflexivity.
    Qed.

    Definition ComputableSentMessages_has_not_been_sent
      {Hsm : ComputableSentMessages}
      (s : vstate vlsm)
      (m : message)
      : Prop
      :=
      ~ ComputableSentMessages_has_been_sent s m.

    Lemma ComputableSentMessages_has_not_been_sent_proper
      {Hsm : ComputableSentMessages}
      (s : state)
      (Hs : valid_state_prop pre_vlsm s)
      (m : message)
      : has_not_been_sent_prop ComputableSentMessages_has_not_been_sent s m.
    Proof.
      unfold has_not_been_sent_prop. unfold no_traces_have_message_prop.
      unfold ComputableSentMessages_has_not_been_sent.
      unfold ComputableSentMessages_has_been_sent.
      split.
      - intro Hin.
        cut (~ selected_message_exists_in_some_preloaded_traces (field_selector output) s m).
        { intros Hno is tr Htr Hexists.
          contradict Hno;exists is, tr, Htr;assumption.
        }
        contradict Hin.
        apply sent_messages_full;[assumption|].
        exists (exist _ m Hin).
        reflexivity.
      - intros Htrace Hin.
        apply sent_messages_full in Hin;[|assumption].
        destruct Hin as [[m0 Hm] Heq];simpl in Heq;subst m0.
        destruct Hm as [is [tr [Htr Hex]]].
        apply (Htrace is tr Htr Hex).
    Qed.

    Definition ComputableSentMessages_HasBeenSentCapability
      {Hsm : ComputableSentMessages}
      {eq_message : EqDecision message}
      : HasBeenSentCapability
      :=
      {|
        has_been_sent := ComputableSentMessages_has_been_sent;
        proper_sent := ComputableSentMessages_has_been_sent_proper;
        proper_not_sent := ComputableSentMessages_has_not_been_sent_proper
      |}.

    Class ComputableReceivedMessages := {
      received_messages_fn : vstate vlsm -> list message;

      received_messages_full :
        forall (s : vstate vlsm) (Hs : valid_state_prop pre_vlsm s) (m : message),
          m ∈ (received_messages_fn s) <-> exists (sm : received_messages s), proj1_sig sm = m;

      received_messages_consistency :
        forall
          (s : vstate vlsm)
          (Hs : valid_state_prop pre_vlsm s)
          (m : message),
          selected_messages_consistency_prop (field_selector input) s m
    }.

    Lemma ComputableReceivedMessages_initial_state_empty
      {Hrm : ComputableReceivedMessages}
      (s : vinitial_state vlsm)
      : received_messages_fn (proj1_sig s) = [].
    Proof.
      assert (Hps : valid_state_prop pre_vlsm (proj1_sig s))
        by (apply initial_state_is_valid;apply proj2_sig).
      destruct s as [s Hs]. simpl in *.
      destruct (received_messages_fn s) as [|m l] eqn:Hrcv; try reflexivity.
      specialize (received_messages_full s Hps m) as Hl. apply proj1 in Hl.
      spec Hl; try (rewrite Hrcv; left; reflexivity).
      destruct Hl as [[m0 Hm] Heq]. simpl in Heq. subst m0.
      apply received_messages_consistency in Hm; try assumption.
      exfalso. revert Hm.
      apply selected_message_exists_in_all_traces_initial_state.
      assumption.
    Qed.

    Definition ComputableReceivedMessages_has_been_received
      {Hsm : ComputableReceivedMessages}
      (s : vstate vlsm)
      (m : message)
      : Prop
      :=
      m ∈ (received_messages_fn s).

    Global Instance ComputableReceivedMessages_has_been_received_dec
      {Hsm : ComputableReceivedMessages}
      {eq_message : EqDecision message}
      : RelDecision ComputableReceivedMessages_has_been_received
      := fun s m => decide_rel _ _ (received_messages_fn s).

    Lemma ComputableReceivedMessages_has_been_received_proper
      {Hsm : ComputableReceivedMessages}
      (s : state)
      (Hs : valid_state_prop pre_vlsm s)
      (m : message)
      : has_been_received_prop ComputableReceivedMessages_has_been_received s m.
    Proof.
      unfold has_been_received_prop. unfold all_traces_have_message_prop.
      unfold ComputableReceivedMessages_has_been_received.
      split.
      - intro Hin.
        apply received_messages_full in Hin;[|assumption].
        destruct Hin as [[m0 Hm] Heq];simpl in Heq;subst m0.
        apply received_messages_consistency;assumption.
      - intro H. apply received_messages_full;[assumption|].
        apply (received_messages_consistency s Hs m) in H.
        exists (exist _ m H). reflexivity.
    Qed.

    Definition ComputableReceivedMessages_has_not_been_received
      {Hsm : ComputableReceivedMessages}
      (s : vstate vlsm)
      (m : message)
      : Prop
      :=
      ~ ComputableReceivedMessages_has_been_received s m.

    Lemma ComputableReceivedMessages_has_not_been_received_proper
      {Hsm : ComputableReceivedMessages}
      (s : state)
      (Hs : valid_state_prop pre_vlsm s)
      (m : message)
      : has_not_been_received_prop ComputableReceivedMessages_has_not_been_received s m.
    Proof.
      unfold has_not_been_received_prop. unfold no_traces_have_message_prop.
      unfold ComputableReceivedMessages_has_not_been_received.
      unfold ComputableReceivedMessages_has_been_received.
      rewrite <- selected_message_exists_preloaded_not_some_iff_no.
      apply not_iff_compat.
      rewrite received_messages_full;[|assumption].
      unfold received_messages.
      rewrite exists_proj1_sig.
      reflexivity.
    Qed.

    Definition ComputableReceivedMessages_HasBeenReceivedCapability
      {Hsm : ComputableReceivedMessages}
      {eq_message : EqDecision message}
      : HasBeenReceivedCapability
      :=
      {|
        has_been_received := ComputableReceivedMessages_has_been_received;
        proper_received := ComputableReceivedMessages_has_been_received_proper;
        proper_not_received := ComputableReceivedMessages_has_not_been_received_proper
      |}.
End Simple.

(** *** Stepwise consistency properties for [state_message_oracle]

 The above definitions like [all_traces_have_message_prop]
 connect a [state_message_oracle] to a predicate on
 [transition_item] by relating the oracle holding on a state
 to a satsifying transition existing in all traces.

 This is equivalent to two local properties,
 one is that the oracle cannot only for any initial state,
 the other is that the oracle judgement is appropriately
 related for the starting and [destination] states of
 any [input_valid_transition].

 These conditions are defined in the record [oracle_stepwise_props]
 *)

Record oracle_stepwise_props
       [message] [vlsm: VLSM message]
       (message_selector: message -> transition_item -> Prop)
       (oracle: state_message_oracle vlsm) : Prop :=
  {oracle_no_inits: forall (s: vstate vlsm),
      initial_state_prop (VLSMSign:=sign vlsm) s ->
      forall m, ~oracle s m;
   oracle_step_update:
       forall l s im s' om,
         input_valid_transition (pre_loaded_with_all_messages_vlsm vlsm) l (s,im) (s',om) ->
         forall msg, oracle s' msg <->
                     (message_selector msg {|l:=l; input:=im; destination:=s'; output:=om|}
                      \/ oracle s msg)
  }.
Arguments oracle_no_inits {message} {vlsm} {message_selector} {oracle} _.
Arguments oracle_step_update {message} {vlsm} {message_selector} {oracle} _.

Lemma oracle_partial_trace_update
      [message] [vlsm: VLSM message]
      [selector: message -> transition_item -> Prop]
      [oracle: state_message_oracle vlsm]
      (Horacle: oracle_stepwise_props selector oracle)
      s0 s tr
         (Htr: finite_valid_trace_from_to (pre_loaded_with_all_messages_vlsm vlsm) s0 s tr):
    forall m,
      oracle s m
      <-> (trace_has_message selector m tr \/ oracle s0 m).
Proof.
  induction Htr.
  - intro m.
    unfold trace_has_message.
    rewrite Exists_nil.
    tauto.
  - intro m. specialize (IHHtr m).
    unfold trace_has_message.
    rewrite Exists_cons.
    apply (Horacle.(oracle_step_update)) with (msg:=m) in Ht.
    tauto.
Qed.

Lemma oracle_initial_trace_update
      [message] [vlsm: VLSM message]
      [selector]
      [oracle : state_message_oracle vlsm]
      (Horacle: oracle_stepwise_props selector oracle)
      s0 s tr
      (Htr: finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm vlsm) s0 s tr):
  forall m,
    oracle s m <-> trace_has_message selector m tr.
Proof.
  intros m.
  pose proof (oracle_partial_trace_update Horacle _ _ _ (proj1 Htr) m).
  pose proof (oracle_no_inits Horacle s0 (proj2 Htr) m).
  clear -H H0. tauto.
Qed.

(**
   Proving the trace properties from the stepwise properties
   begins with a lemma using induction along a trace to
   prove that given a [finite_valid_trace] to a state,
   the oracle holds at that state for some message iff
   a satsifying transition item exists in the trace.

   The theorems for [all_traces_have_message_prop]
   and [no_traces_have_message_prop] are mostly rearraning
   quantifiers to use this lemma, also using [valid_state_prop]
   to choose a trace to the state for the directions where
   one is not given.
 *)
Section TraceFromStepwise.
  Context
    (message : Type)
    (vlsm: VLSM message)
    (selector : message -> transition_item -> Prop)
    (oracle : state_message_oracle vlsm)
    (oracle_props : oracle_stepwise_props selector oracle)
    .

  Local Lemma H_valid_trace_prop
        [s0 s tr]
        (Htr: finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm vlsm) s0 s tr):
    forall m,
      oracle s m <-> trace_has_message selector m tr.
  Proof.
    intro m.
    destruct Htr as [Htr Hinit].
    rewrite (oracle_partial_trace_update oracle_props _ _ _ Htr).
    assert (~oracle s0 m).
    apply oracle_props, Hinit.
    tauto.
  Qed.

  Lemma prove_all_have_message_from_stepwise:
    forall (s : state)
           (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s)
           (m : message),
      (all_traces_have_message_prop vlsm selector oracle s m).
  Proof.
    intros s Hproto m.
    unfold all_traces_have_message_prop.
    split.
    - intros Hsent s0 tr Htr.
      apply (H_valid_trace_prop Htr).
      assumption.
    - intro H_all_traces.
      apply valid_state_has_trace in Hproto.
      destruct Hproto as [s0 [tr Htr]].
      apply (H_valid_trace_prop Htr).
      specialize (H_all_traces s0 tr Htr).
      assumption.
  Qed.

  Lemma prove_none_have_message_from_stepwise:
    forall (s : state)
           (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s)
           (m : message),
      no_traces_have_message_prop vlsm selector (fun s m => ~oracle s m) s m.
  Proof.
    intros s Hproto m.
    pose proof (H_valid_trace_prop).
    split.
    - intros H_not_sent start tr Htr.
      contradict H_not_sent.
      apply (H_valid_trace_prop Htr).
      assumption.
    - intros H_no_traces.
      apply valid_state_has_trace in Hproto.
      destruct Hproto as [s0 [tr Htr]].
      specialize (H_no_traces s0 tr Htr).
      contradict H_no_traces.
      apply (H_valid_trace_prop Htr).
      assumption.
  Qed.

  Lemma selected_messages_consistency_prop_from_stepwise
      (oracle_dec: RelDecision oracle)
      (s : state)
      (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s)
      (m : message)
      : selected_messages_consistency_prop vlsm selector s m.
  Proof.
    split.
    - intro Hsome.
      destruct (decide (oracle s m)) as [Hsm|Hsm].
      + apply prove_all_have_message_from_stepwise in Hsm;assumption.
      + apply prove_none_have_message_from_stepwise in Hsm;[|assumption].
        exfalso.
        destruct Hsome as [is [tr [Htr Hmsg]]].
        elim (Hsm _ _ Htr).
        assumption.
    - apply consistency_from_valid_state_proj2.
      assumption.
  Qed.

  Lemma in_futures_preserving_oracle_from_stepwise:
    forall (s1 s2: state)
      (Hfutures : in_futures (pre_loaded_with_all_messages_vlsm vlsm) s1 s2)
      (m : message),
      oracle s1 m -> oracle  s2 m.
  Proof.
    intros s1 s2 [tr Htr] m Hs1m.
    apply (oracle_partial_trace_update oracle_props _ _ _ Htr).
    right;assumption.
  Qed.
End TraceFromStepwise.

(**
   The stepwise properties are proven from the trace properties
   by considering the empty trace to prove the [oracle_no_inits]
   property, and by considering a trace that ends with the given
   [input_valid_transition] to prove the [oracle_step_update] property.
 *)
Section StepwiseFromTrace.
  Context
    (message : Type)
    (vlsm: VLSM message)
    (selector: message -> transition_item -> Prop)
    (oracle: state_message_oracle vlsm)
    (oracle_dec: RelDecision oracle)
    (Horacle_all_have:
       forall s (Hs: valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s) m,
        all_traces_have_message_prop vlsm selector oracle s m)
    (Hnot_oracle_none_have:
       forall s (Hs: valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s) m,
         no_traces_have_message_prop vlsm selector (fun m s => ~oracle m s) s m).

  Lemma oracle_no_inits_from_trace:
    forall (s: vstate vlsm), initial_state_prop (VLSMSign:=sign vlsm) s ->
                             forall m, ~oracle s m.
  Proof.
    intros s Hinit m Horacle.
    assert (Hproto : valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s)
      by (apply initial_state_is_valid;assumption).
    apply Horacle_all_have in Horacle;[|assumption].
    specialize (Horacle s nil).
    eapply Exists_nil;apply Horacle;clear Horacle.
    split;[constructor|];assumption.
  Qed.

  Lemma examine_one_trace:
    forall is s tr,
      finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm vlsm) is s tr ->
    forall m,
      oracle s m <->
      trace_has_message selector m tr.
  Proof.
    intros is s tr Htr m.
    assert (valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s)
      by (apply valid_trace_last_pstate in Htr;assumption).
    split.
    - intros Horacle.
      apply Horacle_all_have in Horacle;[|assumption].
      specialize (Horacle is tr Htr).
      assumption.
    - intro Hexists.
      apply dec_stable.
      intro Hnot.
      apply Hnot_oracle_none_have in Hnot;[|assumption].
      rewrite <- selected_message_exists_preloaded_not_some_iff_no in Hnot.
      apply Hnot.
      exists is, tr, Htr.
      assumption.
  Qed.

  Lemma oracle_step_property_from_trace:
       forall l s im s' om,
         input_valid_transition (pre_loaded_with_all_messages_vlsm vlsm) l (s,im) (s',om) ->
         forall msg, oracle s' msg
                     <-> (selector msg {| l:=l; input:=im; destination:=s'; output:=om |}
                          \/ oracle s msg).
  Proof.
    intros l s im s' om Htrans msg.
    rename Htrans into Htrans'.
    pose proof Htrans' as [[Hproto_s [Hproto_m Hvalid]] Htrans].
    set (preloaded:= pre_loaded_with_all_messages_vlsm vlsm) in * |- *.

    pose proof (valid_state_has_trace _ _ Hproto_s)
      as [is [tr [Htr Hinit]]].

    pose proof (Htr' := extend_right_finite_trace_from_to _ Htr Htrans').

    rewrite (examine_one_trace _ _ _ (conj Htr Hinit) msg).
    rewrite (examine_one_trace _ _ _ (conj Htr' Hinit) msg).
    clear.
    progress cbn. unfold trace_has_message.
    rewrite Exists_app, Exists_cons, Exists_nil.
    tauto.
  Qed.

  Lemma stepwise_props_from_trace : oracle_stepwise_props selector oracle.
  Proof.
    constructor.
    refine oracle_no_inits_from_trace.
    refine oracle_step_property_from_trace.
  Defined.
End StepwiseFromTrace.

(** ** Stepwise view of [HasBeenSentCapability]

This reduces the proof obligations in [HasBeenSentCapability]
to proving the stepwise properties of [oracle_stepwise_props].
[has_been_step_stepwise_props] is a specialization of [oracle_stepwise_props]
to the right <<message_selector>>.

There are also lemmas for accessing the stepwise properties about
a [has_been_sent] predicate given an instance of [HasBeenSentCapability], to allow using
[HasBeenSentCapability_from_stepwise] to define a [HasBeenSentCapability]
for composite VLSMs, or for proofs (e.g, about invariants) where
these are more convenient.
 **)

Definition has_been_sent_stepwise_props
       [message] [vlsm: VLSM message] (has_been_sent_pred: state_message_oracle vlsm) : Prop :=
  (oracle_stepwise_props (field_selector output) has_been_sent_pred).

Lemma HasBeenSentCapability_from_stepwise
      [message : Type]
      [vlsm: VLSM message]
      [has_been_sent_pred: state_message_oracle vlsm]
      (has_been_sent_pred_dec: RelDecision has_been_sent_pred)
      (has_been_sent_alt_props: has_been_sent_stepwise_props has_been_sent_pred):
  HasBeenSentCapability vlsm.
Proof.
  refine ({|has_been_sent:=has_been_sent_pred|}).
  apply prove_all_have_message_from_stepwise;assumption.
  apply prove_none_have_message_from_stepwise;assumption.
Defined.

Lemma has_been_sent_stepwise_from_trace
      [message : Type]
      [vlsm: VLSM message]
      (Hhbs: HasBeenSentCapability vlsm):
  oracle_stepwise_props (field_selector output) (has_been_sent vlsm).
Proof.
  apply stepwise_props_from_trace.
  apply has_been_sent_dec.
  apply proper_sent.
  apply proper_not_sent.
Defined.

Lemma has_been_sent_step_update
      `{Hhbs: HasBeenSentCapability message vlsm}:
  forall [l s im s' om],
    input_valid_transition (pre_loaded_with_all_messages_vlsm vlsm) l (s,im) (s',om) ->
    forall m,
      has_been_sent vlsm s' m <-> (om = Some m \/ has_been_sent vlsm s m).
Proof.
  exact (oracle_step_update (has_been_sent_stepwise_from_trace Hhbs)).
Qed.

Lemma has_been_sent_examine_one_trace
  `(Hhbs: HasBeenSentCapability message vlsm):
  forall is s tr,
    finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm vlsm) is s tr ->
  forall m,
    has_been_sent vlsm s m <->
    trace_has_message (field_selector output) m tr.
Proof.
  destruct Hhbs.
  apply examine_one_trace; assumption.
Qed.

(** ** Stepwise view of [HasBeenReceivedCapability] *)

Definition has_been_received_stepwise_props
       [message] [vlsm: VLSM message] (has_been_received_pred: state_message_oracle vlsm) : Prop :=
  (oracle_stepwise_props (field_selector input) has_been_received_pred).

Lemma HasBeenReceivedCapability_from_stepwise
      [message : Type]
      [vlsm: VLSM message]
      [has_been_received_pred: state_message_oracle vlsm]
      (has_been_received_pred_dec: RelDecision has_been_received_pred)
      (has_been_sent_alt_props: has_been_received_stepwise_props has_been_received_pred):
  HasBeenReceivedCapability vlsm.
Proof.
  refine ({|has_been_received:=has_been_received_pred|}).
  apply prove_all_have_message_from_stepwise;assumption.
  apply prove_none_have_message_from_stepwise;assumption.
Defined.

Lemma has_been_received_stepwise_from_trace
      [message : Type]
      [vlsm: VLSM message]
      (Hhbr: HasBeenReceivedCapability vlsm):
  oracle_stepwise_props (field_selector input) (has_been_received vlsm).
Proof.
  apply stepwise_props_from_trace.
  apply has_been_received_dec.
  apply proper_received.
  apply proper_not_received.
Defined.

Lemma has_been_received_step_update
      `{Hhbs: HasBeenReceivedCapability message vlsm}:
  forall [l s im s' om],
    input_valid_transition (pre_loaded_with_all_messages_vlsm vlsm) l (s,im) (s',om) ->
    forall m,
      has_been_received vlsm s' m <-> (im = Some m \/ has_been_received vlsm s m).
Proof.
  exact (oracle_step_update (has_been_received_stepwise_from_trace Hhbs)).
Qed.

Lemma has_been_received_examine_one_trace
  `(Hhbr: HasBeenReceivedCapability message vlsm):
  forall is s tr,
    finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm vlsm) is s tr ->
  forall m,
    has_been_received vlsm s m <->
    trace_has_message (field_selector input) m tr.
Proof.
  destruct Hhbr.
  apply examine_one_trace; assumption.
Qed.

Lemma trace_to_initial_state_has_no_inputs
  `{Hbr: HasBeenReceivedCapability message vlsm}
  is s tr
  (Htr : finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm vlsm) is s tr)
  (Hs : vinitial_state_prop vlsm s)
  : forall item, In item tr -> input item = None.
Proof.
  intros item Hitem.
  destruct (input item) as [m|] eqn:Heqm; [|reflexivity].
  elim (selected_message_exists_in_all_traces_initial_state _ _ Hs (field_selector input) m).
  apply has_been_received_consistency; [assumption|apply initial_state_is_valid; assumption|].
  eexists _,_, Htr.
  apply Exists_exists. exists item. split; [|assumption].
  apply elem_of_list_In. assumption.
Qed.

(** ** A state message oracle for messages sent or received

In protocols like the CBC full node protocol, validators often
work with the set of all messages they have directly observed,
which includes the messages the node sent itself along with
messages that were received.
The [has_been_observed] oracle holds for a message if the
message was sent or received in any transition.
*)

Class HasBeenObservedCapability {message} (vlsm: VLSM message) :=
  {
  has_been_observed: state_message_oracle vlsm;
  has_been_observed_dec :> RelDecision has_been_observed;
  has_been_observed_stepwise_props: oracle_stepwise_props item_sends_or_receives has_been_observed;
  }.
Arguments has_been_observed {message} vlsm {_}.
Arguments has_been_observed_dec {message} vlsm {_}.

Definition has_been_observed_no_inits `{Hhbo: HasBeenObservedCapability message vlsm}
  := oracle_no_inits has_been_observed_stepwise_props.

Definition has_been_observed_step_update `{Hhbo: HasBeenObservedCapability message vlsm} :
  forall l s im s' om,
    input_valid_transition (pre_loaded_with_all_messages_vlsm vlsm) l (s, im) (s', om) ->
    forall msg,
      has_been_observed vlsm s' msg <->
      ((im = Some msg \/ om = Some msg) \/ has_been_observed vlsm s msg)
  := oracle_step_update has_been_observed_stepwise_props.

Lemma proper_observed `(Hhbo: HasBeenObservedCapability message vlsm):
  forall (s:state),
    valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s ->
    forall m,
      all_traces_have_message_prop vlsm item_sends_or_receives (has_been_observed vlsm) s m.
Proof.
  intros.
  apply prove_all_have_message_from_stepwise.
  apply Hhbo.
  assumption.
Qed.

Lemma proper_not_observed `(Hhbo: HasBeenObservedCapability message vlsm):
  forall (s:state),
    valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s ->
    forall m,
      no_traces_have_message_prop vlsm item_sends_or_receives
                                  (fun s m => ~has_been_observed vlsm s m) s m.
Proof.
  intros.
  apply prove_none_have_message_from_stepwise.
  apply Hhbo.
  assumption.
Qed.

Lemma has_been_observed_examine_one_trace
  `(Hhbo: HasBeenObservedCapability message vlsm):
  forall is s tr,
    finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm vlsm) is s tr ->
  forall m,
    has_been_observed vlsm s m <->
    trace_has_message item_sends_or_receives m tr.
Proof.
  apply examine_one_trace.
  - apply has_been_observed_dec.
  - apply proper_observed.
  - apply proper_not_observed.
Qed.

(** A received message introduces no additional equivocations to a state
    if it has already been observed in s.
*)
Definition no_additional_equivocations
  {message : Type}
  (vlsm : VLSM message)
  {Hbo : HasBeenObservedCapability vlsm}
  (s : state)
  (m : message)
  : Prop
  :=
  has_been_observed vlsm s m.

(** [no_additional_equivocations] is decidable.
*)

Lemma no_additional_equivocations_dec
  {message : Type}
  (vlsm : VLSM message)
  {Hbo : HasBeenObservedCapability vlsm}
  : RelDecision (no_additional_equivocations vlsm).
Proof.
  apply has_been_observed_dec.
Qed.

Definition no_additional_equivocations_constraint
  {message : Type}
  (vlsm : VLSM message)
  {Hbo : HasBeenObservedCapability vlsm}
  (l : vlabel vlsm)
  (som : state * option message)
  : Prop
  :=
  let (s, om) := som in
  from_option (no_additional_equivocations vlsm s) True om.

Section sent_received_observed_capabilities.

Context
  {message : Type}
  (vlsm : VLSM message)
  {Hbr : HasBeenReceivedCapability vlsm}
  {Hbs : HasBeenSentCapability vlsm}
  .

Lemma has_been_observed_sent_received_iff
  {Hbo : HasBeenObservedCapability vlsm}
  (s : state)
  (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s)
  (m : message)
  : has_been_observed vlsm s m <-> has_been_received vlsm s m \/ has_been_sent vlsm s m.
Proof.
  specialize
    (prove_all_have_message_from_stepwise message vlsm  item_sends_or_receives
    (has_been_observed vlsm) has_been_observed_stepwise_props _ Hs m) as Hall.
  split; [intro H | intros [H | H]].
  - apply proj1 in Hall. specialize (Hall H).
    apply consistency_from_valid_state_proj2 in Hall; [|assumption].
    destruct Hall as [is [tr [Htr Hexists]]].
    apply Exists_or_inv in Hexists.
    destruct Hexists as [Hsent | Hreceived].
    + left. specialize (has_been_received_consistency vlsm _ Hs m) as Hcons.
      apply proper_received; [assumption|].
      apply Hcons. exists is, tr, Htr. assumption.
    + right. specialize (has_been_sent_consistency vlsm _ Hs m) as Hcons.
      apply proper_sent; [assumption|].
      apply Hcons. exists is, tr, Htr. assumption.
  - apply Hall.
    intro is; intros.
    apply proper_received in H; [|assumption]. specialize (H is tr Htr).
    apply Exists_or. left. assumption.
  - apply Hall.
    intro is; intros.
    apply proper_sent in H; [|assumption]. specialize (H is tr Htr).
    apply Exists_or. right. assumption.
Qed.

Definition has_been_observed_from_sent_received
  (s : vstate vlsm)
  (m : message)
  : Prop
  := has_been_sent vlsm s m \/ has_been_received vlsm s m.

Lemma has_been_observed_from_sent_received_dec
  : RelDecision has_been_observed_from_sent_received.
Proof.
  intros s m.
  apply Decision_or.
  - apply has_been_sent_dec.
  - apply has_been_received_dec.
Qed.

Lemma has_been_observed_from_sent_received_stepwise_props
  : oracle_stepwise_props item_sends_or_receives has_been_observed_from_sent_received.
Proof.
  apply stepwise_props_from_trace; [apply has_been_observed_from_sent_received_dec|..]
  ; intros; split; intros.
  - intro; intros.
    destruct H as [H | H].
    + apply proper_sent in H; [|apply Hs]. specialize (H _ _ Htr).
      apply Exists_or. right. assumption.
    + apply proper_received in H; [|apply Hs]. specialize (H _ _ Htr).
      apply Exists_or. left. assumption.
  - apply consistency_from_valid_state_proj2 in H; [|assumption].
    destruct H as [is [tr [Htr Hexists]]].
    apply Exists_or_inv in Hexists.
    destruct Hexists as [Hsent | Hreceived].
    + right. apply proper_received; [assumption|].
      apply has_been_received_consistency; [assumption|assumption|].
      exists is, tr, Htr. assumption.
    + left. apply proper_sent; [assumption|].
      apply has_been_sent_consistency; [assumption|assumption|].
      exists is, tr, Htr. assumption.
  - intro; intros. intro Hexists. elim H.
    apply Exists_or_inv in Hexists.
    destruct Hexists as [Hexists| Hexists].
    + right. apply proper_received; [assumption|].
      apply has_been_received_consistency; [assumption|assumption|].
      exists start, tr, Htr. assumption.
    + left. apply proper_sent; [assumption|].
      apply has_been_sent_consistency; [assumption|assumption|].
      exists start, tr, Htr. assumption.
  - intros [Hobs | Hobs].
    + apply proper_sent in Hobs; [|assumption].
      apply has_been_sent_consistency in Hobs; [|assumption|assumption].
      destruct Hobs as [is [tr [Htr Hexists]]].
      specialize (H _ _ Htr). elim H. apply Exists_or. right. assumption.
    + apply proper_received in Hobs; [|assumption].
      apply has_been_received_consistency in Hobs; [|assumption|assumption].
      destruct Hobs as [is [tr [Htr Hexists]]].
      specialize (H _ _ Htr). elim H. apply Exists_or. left. assumption.
Qed.

Local Program Instance HasBeenObservedCapability_from_sent_received
  : HasBeenObservedCapability vlsm
  :=
  { has_been_observed := has_been_observed_from_sent_received;
    has_been_observed_dec := has_been_observed_from_sent_received_dec;

    has_been_observed_stepwise_props := has_been_observed_from_sent_received_stepwise_props
  }.

  Lemma has_been_observed_consistency
    {Hbo : HasBeenObservedCapability vlsm}
    (s : state)
    (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm vlsm) s)
    (m : message)
    : selected_messages_consistency_prop vlsm item_sends_or_receives s m.
  Proof.
    split.
    - intro Hsome.
      destruct (decide (has_been_observed vlsm s m)) as [Hsm|Hsm].
      apply (proper_observed Hbo) in Hsm;assumption.
      apply (proper_not_observed Hbo) in Hsm;[|assumption].
      exfalso.
      destruct Hsome as [is [tr [Htr Hmsg]]].
      elim (Hsm _ _ Htr).
      assumption.
    - apply consistency_from_valid_state_proj2.
      assumption.
  Qed.

End sent_received_observed_capabilities.

Lemma sent_valid
    [message]
    (X : VLSM message)
    {Hhbs: HasBeenSentCapability X}
    (s : state)
    (Hs : valid_state_prop X s)
    (m : message)
    (Hsent : has_been_sent X s m) :
    valid_message_prop X m.
Proof.
  induction Hs using valid_state_prop_ind.
  - contradict Hsent. apply (oracle_no_inits (has_been_sent_stepwise_from_trace Hhbs));assumption.
  - apply input_valid_transition_out in Ht as Hom'.
    apply preloaded_weaken_input_valid_transition in Ht.
    apply (oracle_step_update (has_been_sent_stepwise_from_trace Hhbs) _ _ _ _ _ Ht) in Hsent.
    destruct Hsent.
    + simpl in H. subst om'. assumption.
    + auto.
Qed.

(** *** Equivocation in compositions

 We now move on to a composite context. Each component of our composition
    will have [has_been_sent] and [has_been_received] capabilities.

    We introduce [validator]s along with their respective [Weight]s, the
    [A] function which maps validators to indices of component VLSMs and
    the [sender] function which maps messages to their (unique) designated
    sender (if any).

    For the equivocation fault sum to be computable, we also require that
    the number of [validator]s and the number of machines in the
    composition are both finite. See [finite_index], [finite_validator].
**)

Section Composite.

  Context {message : Type}
          {index : Type}
          {IndEqDec : EqDecision index}
          (IM : index -> VLSM message)
          (Free := free_composite_vlsm IM)
          {index_listing : list index}
          (finite_index : Listing index_listing)
          (has_been_sent_capabilities : forall i : index, (HasBeenSentCapability (IM i)))
          (has_been_observed_capabilities : forall i : index, (HasBeenObservedCapability (IM i)))
          .

  Section StepwiseProps.
    Context
      [message_selectors: forall i : index, message -> vtransition_item (IM i) -> Prop]
      [oracles: forall i, state_message_oracle (IM i)]
      (stepwise_props: forall i, oracle_stepwise_props (message_selectors i) (oracles i))
      .

      Definition composite_message_selector : message -> composite_transition_item IM -> Prop.
      Proof.
        intros msg [[i li] input s output].
        apply (message_selectors i msg).
        exact {|l:=li;input:=input;destination:=s i;output:=output|}.
      Defined.

      Definition composite_oracle : composite_state IM -> message -> Prop :=
        fun s msg => exists i, oracles i (s i) msg.

      Lemma composite_stepwise_props
        (constraint : composite_label IM -> composite_state IM * option message -> Prop)
        (X := composite_vlsm IM constraint)
        : oracle_stepwise_props (vlsm := X) composite_message_selector composite_oracle.
      Proof.
        split.
        - (* initial states not claim *)
          intros s Hs m [i H].
          revert H.
          fold (~ oracles i (s i) m).
          apply (oracle_no_inits (stepwise_props i)).
          apply Hs.
        - (* step update property *)
          intros l s im s' om Hproto msg.
          destruct l as [i li].
          simpl.
          assert (forall j, s j = s' j \/ j = i).
          {
            intro j.
            apply (input_valid_transition_preloaded_project_any j) in Hproto.
            destruct Hproto;[left;assumption|right].
            destruct H as [lj [Hlj _]].
            congruence.
          }
          apply input_valid_transition_preloaded_project_active in Hproto;simpl in Hproto.
          apply (oracle_step_update (stepwise_props i)) with (msg:=msg) in Hproto.
          split.
          + intros [j Hj].
            destruct (H j) as [Hunchanged|Hji].
            * right;exists j;rewrite Hunchanged;assumption.
            * subst j.
              apply Hproto in Hj.
              destruct Hj;[left;assumption|right;exists i;assumption].
          + intros [Hnow | [j Hbefore]].
            * exists i.
              apply Hproto.
              left;assumption.
            * exists j.
              destruct (H j) as [Hunchanged| ->].
              -- rewrite <- Hunchanged;assumption.
              -- apply Hproto.
                 right.
                 assumption.
      Qed.
  End StepwiseProps.

  (** A message 'has_been_sent' for a composite state if it 'has_been_sent' for any of
  its components.*)
  Definition composite_has_been_sent
    (s : composite_state IM)
    (m : message)
    : Prop
    := exists (i : index), has_been_sent (IM i) (s i) m.

  (** 'composite_has_been_sent' is decidable. *)
  Lemma composite_has_been_sent_dec : RelDecision composite_has_been_sent.
  Proof.
    intros s m.
    apply (Decision_iff (P:=List.Exists (fun i => has_been_sent (IM i) (s i) m) index_listing)).
    - rewrite <- exists_finite by (apply finite_index). reflexivity.
    - typeclasses eauto.
  Qed.

  Lemma composite_has_been_sent_stepwise_props
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    : has_been_sent_stepwise_props (vlsm := X) composite_has_been_sent.
  Proof.
    unfold has_been_sent_stepwise_props.
    pose proof (composite_stepwise_props
                  (fun i => has_been_sent_stepwise_from_trace
                              (has_been_sent_capabilities i)))
         as [Hinits Hstep].
    split;[exact Hinits|].
    (* <<exact Hstep>> doesn't work because [composite_message_selector]
       pattern matches on the label l, so we instantiate and destruct
       to let that simplify *)
    intros l;specialize (Hstep l);destruct l.
    exact Hstep.
  Qed.

  Definition composite_HasBeenSentCapability
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    : HasBeenSentCapability X :=
    HasBeenSentCapability_from_stepwise (vlsm := X)
      composite_has_been_sent_dec
      (composite_has_been_sent_stepwise_props constraint).

  Global Instance free_composite_HasBeenSentCapability : HasBeenSentCapability Free :=
    composite_HasBeenSentCapability (free_constraint IM).

  Lemma preloaded_composite_has_been_sent_stepwise_props
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (seed : message -> Prop)
    (X := pre_loaded_vlsm (composite_vlsm IM constraint) seed)
    : has_been_sent_stepwise_props (vlsm := X) composite_has_been_sent.
  Proof.
    unfold has_been_sent_stepwise_props.
    pose proof (composite_stepwise_props
                  (fun i => has_been_sent_stepwise_from_trace
                              (has_been_sent_capabilities i)))
         as [Hinits Hstep].
    split;[exact Hinits|].
    (* <<exact Hstep>> doesn't work because [composite_message_selector]
       pattern matches on the label l, so we instantiate and destruct
       to let that simplify *)
    intros l;specialize (Hstep l);destruct l.
    exact Hstep.
  Qed.

  Definition preloaded_composite_HasBeenSentCapability
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (seed : message -> Prop)
    (X := pre_loaded_vlsm (composite_vlsm IM constraint) seed)
    : HasBeenSentCapability X :=
    HasBeenSentCapability_from_stepwise (vlsm := X)
      composite_has_been_sent_dec
      (preloaded_composite_has_been_sent_stepwise_props constraint seed).

  Lemma composite_proper_sent
    (s : state)
    (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm (free_composite_vlsm IM)) s)
    (m : message)
    : has_been_sent_prop (free_composite_vlsm IM) composite_has_been_sent s m.
  Proof.
    specialize (proper_sent (free_composite_vlsm IM)) as Hproper_sent.
    apply Hproper_sent.
    assumption.
  Qed.

  Section composite_has_been_received.

  Context
        (has_been_received_capabilities : forall i : index, (HasBeenReceivedCapability (IM i)))
        .

  (** A message 'has_been_received' for a composite state if it 'has_been_received' for any of
  its components.*)
  Definition composite_has_been_received
    (s : composite_state IM)
    (m : message)
    : Prop
    := exists (i : index), has_been_received (IM i) (s i) m.

  (** 'composite_has_been_received' is decidable. *)
  Lemma composite_has_been_received_dec : RelDecision composite_has_been_received.
  Proof.
    intros s m.
    apply (Decision_iff (P:=List.Exists (fun i => has_been_received (IM i) (s i) m) index_listing)).
    - rewrite <- exists_finite by (apply finite_index). reflexivity.
    - typeclasses eauto.
  Qed.

  Lemma composite_has_been_received_stepwise_props
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    : has_been_received_stepwise_props (vlsm := X) composite_has_been_received.
  Proof.
    unfold has_been_received_stepwise_props.
    pose proof (composite_stepwise_props
                  (fun i => has_been_received_stepwise_from_trace
                              (has_been_received_capabilities i)))
         as [Hinits Hstep].
    split;[exact Hinits|].
    (* <<exact Hstep>> doesn't work because [composite_message_selector]
       pattern matches on the label l, so we instantiate and destruct
       to let that simplify *)
    intros l;specialize (Hstep l);destruct l.
    exact Hstep.
  Qed.

  Definition composite_HasBeenReceivedCapability
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    : HasBeenReceivedCapability X :=
    HasBeenReceivedCapability_from_stepwise (vlsm := X)
      composite_has_been_received_dec
      (composite_has_been_received_stepwise_props constraint).

  Global Instance free_composite_HasBeenReceivedCapability : HasBeenReceivedCapability Free :=
    composite_HasBeenReceivedCapability (free_constraint IM).

  End composite_has_been_received.


  (** A message 'has_been_observed' for a composite state if it 'has_been_observed' for any of
  its components.*)
  Definition composite_has_been_observed
    (s : composite_state IM)
    (m : message)
    : Prop
    := exists (i : index), has_been_observed (IM i) (s i) m.

  (** 'composite_has_been_observed' is decidable. *)
  Lemma composite_has_been_observed_dec : RelDecision composite_has_been_observed.
  Proof.
    intros s m.
    apply (Decision_iff (P:=List.Exists (fun i => has_been_observed (IM i) (s i) m) index_listing)).
    - rewrite <- exists_finite by (apply finite_index). reflexivity.
    - typeclasses eauto.
  Qed.

  Lemma composite_has_been_observed_stepwise_props
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    : oracle_stepwise_props (vlsm := X) item_sends_or_receives composite_has_been_observed.
  Proof.
    pose proof (composite_stepwise_props
                  (fun i => has_been_observed_stepwise_props))
         as [Hinits Hstep].
    split;[exact Hinits|].
    intros l;specialize (Hstep l);destruct l.
    exact Hstep.
  Qed.

  Definition composite_HasBeenObservedCapability
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    : HasBeenObservedCapability X.
  Proof.
    exists composite_has_been_observed.
    - apply composite_has_been_observed_dec.
    - apply (composite_has_been_observed_stepwise_props constraint).
  Defined.

  Global Instance free_composite_HasBeenObservedCapability : HasBeenObservedCapability Free :=
    composite_HasBeenObservedCapability (free_constraint IM).

  Context
        {validator : Type}
        (A : validator -> index)
        (sender : message -> option validator)
        .

  Definition node_signed_message (node_idx : index) (m : message) : Prop :=
    option_map A (sender m) = Some node_idx.

  (** Definitions for safety and nontriviality of the [sender] function.
      Safety means that if we designate a validator as the sender
      of a certain messsage, then it is impossible for other components
      to produce that message

      Weak/strong nontriviality say that each validator should
      be designated sender for at least one/all its valid
      messages.
  **)
  Definition sender_safety_prop : Prop :=
    forall
    (m : message)
    (v : validator)
    (Hsender : sender m = Some v),
    forall (j : index)
           (Hdif : j <> A v),
           ~can_emit (pre_loaded_with_all_messages_vlsm (IM j)) m.

   (** An alternative, possibly friendlier, formulation. Note that it is
       slightly weaker, in that it does not require that the sender
       is able to send the message. **)

  Definition sender_safety_alt_prop : Prop :=
    forall
    (m : message)
    (v : validator)
    (Hsender : sender m = Some v),
    forall (i : index),
    can_emit (pre_loaded_with_all_messages_vlsm (IM i)) m ->
    A v = i.

  Lemma sender_safety_alt_iff
    : sender_safety_prop <-> sender_safety_alt_prop.
  Proof.
    split; intros Hsender_safety m; intros.
    - specialize (Hsender_safety m v Hsender).
      destruct (decide (i = A v)); [congruence|].
      elim (Hsender_safety _ n). assumption.
    - intro Hemit. elim Hdif.
      specialize (Hsender_safety m v Hsender _ Hemit).
      congruence.
  Qed.

  Definition channel_authenticated_message (node_idx : index) (m : message) : Prop :=
    option_map A (sender m) = Some node_idx.

  (** The [channel_authentication_prop]erty requires that any sent message must
  be originating with its <<sender>>.
  Note that we don't require that <<sender>> is total, but rather that it is
  defined for all messages which can be emitted.
  *)
  Definition channel_authentication_prop : Prop :=
    forall i m,
    can_emit (pre_loaded_with_all_messages_vlsm (IM i)) m ->
    channel_authenticated_message i m.

  (** Channel authentication guarantees sender safety *)
  Lemma channel_authentication_sender_safety
    : channel_authentication_prop -> sender_safety_alt_prop.
  Proof.
    intros Hsigned m v Hsender i Hemit.
    apply Some_inj.
    change (Some (A v)) with (option_map A (Some v)).
    rewrite <- Hsender.
    apply Hsigned; assumption.
  Qed.

  Definition sender_nontriviality_prop : Prop :=
    forall (v : validator),
    exists (m : message),
    can_emit (pre_loaded_with_all_messages_vlsm (IM (A v))) m /\
    sender m = Some v.

  Definition no_initial_messages_in_IM_prop : Prop :=
    forall i m, ~vinitial_message_prop (IM i) m.

  Lemma composite_no_initial_valid_messages_have_sender
      (can_emit_signed : channel_authentication_prop)
      (no_initial_messages_in_IM : no_initial_messages_in_IM_prop)
      (constraint : composite_label IM -> composite_state IM * option message -> Prop)
      (X := composite_vlsm IM constraint)
      : forall (m : message) (Hm : valid_message_prop X m), sender m <> None.
  Proof.
    intros m Hm Hsender.
    apply emitted_messages_are_valid_iff in Hm.
    destruct Hm as [Hinitial | Hemit].
    - destruct Hinitial as [i [[mi Hmi] Hom]].
      simpl in Hom. subst.
      apply (no_initial_messages_in_IM i m).
      assumption.
    - destruct Hemit as [(s, om) [(i, l) [s' Ht]]].
      specialize (can_emit_signed i m).
      unfold channel_authenticated_message in can_emit_signed.
      rewrite Hsender in can_emit_signed. simpl in can_emit_signed.
      spec can_emit_signed; [|congruence].
      red. eexists _, _, _.
      apply (VLSM_incl_input_valid_transition (constraint_preloaded_free_incl IM _)) in Ht.
      apply pre_loaded_with_all_messages_projection_input_valid_transition_eq with (j := i) in Ht; [|reflexivity].
      exact Ht.
  Qed.

  Lemma has_been_sent_iff_by_sender
        (Hsender_safety : sender_safety_alt_prop)
        [is s tr] (Htr : finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm (free_composite_vlsm IM)) is s tr)
        [m v] (Hsender : sender m = Some v):
    composite_has_been_sent s m <-> has_been_sent (IM (A v)) (s (A v)) m.
  Proof.
    split;[|exists (A v);assumption].
    intros [i Hi].
    rewrite (Hsender_safety _ _ Hsender i);[assumption|].
    assert (finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm (IM i)) (is i) (s i)
                                          (VLSM_projection_trace_project (preloaded_component_projection IM i) tr)).
    {
      rewrite <- (valid_trace_get_last Htr).
      apply valid_trace_forget_last in Htr.
      destruct Htr as [Htr Hinit].
      apply valid_trace_add_last.
      split. revert Htr;apply preloaded_finite_valid_trace_projection.
      exact (Hinit i).
      symmetry.
      apply (VLSM_projection_finite_trace_last (preloaded_component_projection IM i)).
      assumption.
    }
    apply (can_emit_from_valid_trace (pre_loaded_with_all_messages_vlsm (IM i)) (is i) m
                                        (VLSM_projection_trace_project (preloaded_component_projection IM i) tr)).
    exact (valid_trace_forget_last H).
    apply (oracle_initial_trace_update (has_been_sent_stepwise_from_trace (has_been_sent_capabilities i)) (is i) (s i)).
    assumption.
    assumption.
  Qed.

  Lemma no_additional_equivocations_constraint_dec
    : RelDecision (no_additional_equivocations_constraint Free).
  Proof.
    intros l (s, om).
    destruct om; [|left; exact I].
    apply no_additional_equivocations_dec.
  Qed.

  Context
        (has_been_received_capabilities : forall i : index, (HasBeenReceivedCapability (IM i)))
        .

   (** We say that a validator <v> (with associated component <i>) is equivocating wrt.
   to another component <j>, if there exists a message which [has_been_received] by
   <j> but [has_not_been_sent] by <i> **)

  Definition equivocating_wrt
    (v : validator)
    (j : index)
    (sv sj : state)
    (i := A v)
    : Prop
    :=
    exists (m : message),
    sender(m) = Some v /\
    has_not_been_sent  (IM i) sv m /\
    has_been_received  (IM j) sj m.

  (** We can now decide whether a validator is equivocating in a certain state. **)

  Definition is_equivocating_statewise
    (s : composite_state IM)
    (v : validator)
    : Prop
    :=
    exists (j : index),
    equivocating_wrt v j (s (A v)) (s j).

  Lemma initial_state_is_not_equivocating_statewise
    (s : composite_state IM)
    (Hs : composite_initial_state_prop IM s)
    (v : validator)
    : ~ is_equivocating_statewise s v.
  Proof.
    unfold is_equivocating_statewise, equivocating_wrt.
    intros [j [m [Hsender [Hnbs Hrcv]]]].
    revert Hrcv.
    apply has_been_received_stepwise_from_trace.
    apply Hs.
  Qed.

  Context
      {validator_listing : list validator}
      (finite_validator : Listing validator_listing)
      {measurable_V : Measurable validator}
      {threshold_V : ReachableThreshold validator}
      .
  (** For the equivocation sum fault to be computable, we require that
      our is_equivocating property is decidable. The current implementation
      refers to [is_equivocating_statewise], but this might change
      in the future **)

  Program Definition equivocation_dec_statewise
     (Hdec : RelDecision is_equivocating_statewise)
      : BasicEquivocation (composite_state IM) (validator)
    :=
    {|
      state_validators := fun _ => validator_listing;
      state_validators_nodup := _;
      is_equivocating := is_equivocating_statewise;
      is_equivocating_dec := Hdec
    |}.
  Next Obligation.
   apply (Listing_NoDup finite_validator).
  Defined.

  Definition equivocation_fault_constraint
    (Dec : BasicEquivocation (composite_state IM) validator)
    (l : composite_label IM)
    (som : composite_state IM * option message)
    : Prop
    :=
    let (s', om') := (composite_transition IM l som) in
    not_heavy s'.

  Lemma messages_sent_from_component_of_valid_state_are_valid
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    (s : composite_state IM)
    (Hs : valid_state_prop X s)
    (i : index)
    (m : message)
    (Hsent : has_been_sent (IM i) (s i) m) :
    valid_message_prop X m.
  Proof.
    pose (Xhbs := composite_HasBeenSentCapability constraint).
    apply (sent_valid X s). assumption. exists i;assumption.
  Qed.

  Lemma preloaded_messages_sent_from_component_of_valid_state_are_valid
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (seed : message -> Prop)
    (X := pre_loaded_vlsm (composite_vlsm IM constraint) seed)
    (s : composite_state IM)
    (Hs : valid_state_prop X s)
    (i : index)
    (m : message)
    (Hsent : has_been_sent (IM i) (s i) m) :
    valid_message_prop X m.
  Proof.
    pose (Xhbs := preloaded_composite_HasBeenSentCapability constraint seed).
    apply (sent_valid X s). assumption. exists i;assumption.
  Qed.

  Lemma messages_received_from_component_of_valid_state_are_valid
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    (s : composite_state IM)
    (Hs : valid_state_prop X s)
    (i : index)
    (m : message)
    (Hreceived : has_been_received (IM i) (s i) m)
    : valid_message_prop X m.
  Proof.
    assert (Hcomp : has_been_received Free s m) by (exists i; assumption).

    apply valid_state_has_trace in Hs as H'.
    destruct H' as [is [tr Hpr]].
    assert (Htr : finite_valid_trace_init_to (pre_loaded_with_all_messages_vlsm Free) is s tr).
    { revert Hpr. apply VLSM_incl_finite_valid_trace_init_to.
      apply VLSM_incl_trans with (MY := machine Free).
      - apply constraint_free_incl with (constraint0 := constraint).
      - apply vlsm_incl_pre_loaded_with_all_messages_vlsm.
    }
    apply valid_trace_input_is_valid with (is0:=is) (tr0:=tr).
    - apply valid_trace_forget_last in Hpr; apply Hpr.
    - apply proper_received in Hcomp; [apply (Hcomp is tr Htr)|].
      apply finite_valid_trace_init_to_last in Htr as Heqs.
      subst s. apply finite_valid_trace_last_pstate.
      apply proj1, finite_valid_trace_from_to_forget_last in Htr.
      assumption.
  Qed.

  Lemma composite_sent_valid
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    (s : composite_state IM)
    (Hs : valid_state_prop X s)
    (m : message)
    (Hsent : composite_has_been_sent s m)
    : valid_message_prop X m.
  Proof.
    destruct Hsent as [i Hsent].
    apply messages_sent_from_component_of_valid_state_are_valid with s i
    ; assumption.
  Qed.

  Lemma preloaded_composite_sent_valid
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (seed : message -> Prop)
    (X := pre_loaded_vlsm (composite_vlsm IM constraint) seed)
    (s : composite_state IM)
    (Hs : valid_state_prop X s)
    (m : message)
    (Hsent : composite_has_been_sent s m)
    : valid_message_prop X m.
  Proof.
    destruct Hsent as [i Hsent].
    apply preloaded_messages_sent_from_component_of_valid_state_are_valid with s i
    ; assumption.
  Qed.

  Lemma composite_received_valid
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    (s : composite_state IM)
    (Hs : valid_state_prop X s)
    (m : message)
    (Hreceived : composite_has_been_received has_been_received_capabilities s m)
    : valid_message_prop X m.
  Proof.
    destruct Hreceived as [i Hreceived].
    apply messages_received_from_component_of_valid_state_are_valid with s i
    ; assumption.
  Qed.

  Lemma composite_observed_valid
    (constraint : composite_label IM -> composite_state IM * option message -> Prop)
    (X := composite_vlsm IM constraint)
    (s : composite_state IM)
    (Hs : valid_state_prop X s)
    (m : message)
    (Hobserved : composite_has_been_observed s m)
    : valid_message_prop X m.
  Proof.
    destruct Hobserved as [i Hobserved].
    apply (has_been_observed_sent_received_iff (IM i)) in Hobserved.
    - destruct Hobserved as [Hreceived | Hsent].
      + apply messages_received_from_component_of_valid_state_are_valid with s i; assumption.
      + apply messages_sent_from_component_of_valid_state_are_valid with s i; assumption.
    - revert Hs. apply valid_state_project_preloaded.
  Qed.
End Composite.

  Lemma composite_has_been_observed_sent_received_iff
    {message}
    `{IndEqDec : EqDecision index}
    (IM : index -> VLSM message)
    (Hbs : forall i : index, HasBeenSentCapability (IM i))
    (Hbr : forall i : index, HasBeenReceivedCapability (IM i))
    (Hbo : forall i : index, HasBeenObservedCapability (IM i)
      := fun i => HasBeenObservedCapability_from_sent_received (IM i))
    (s : composite_state IM)
    (m : message)
    : composite_has_been_observed IM Hbo s m <-> composite_has_been_sent IM Hbs s m \/ composite_has_been_received IM Hbr s m.
  Proof.
    split.
    - intros [i [Hs|Hr]]; [left|right]; exists i; assumption.
    - intros [[i Hs] | [i Hr]]; exists i; [left|right]; assumption.
  Qed.

(* Make also A and sender implicit, because they are inferrable from Hsender_safety *)
Arguments has_been_sent_iff_by_sender {message index}%type_scope {IndEqDec} _%function_scope
  _%function_scope {validator}%type_scope {A sender}%function_scope Hsender_safety [is s] [tr]%list_scope _ [m v].

  Lemma lift_to_composite_state_observed
    {message}
    `{IndEqDec : EqDecision index}
    (IM : index -> VLSM message)
    (Hbs : forall i : index, HasBeenSentCapability (IM i))
    (Hbr : forall i : index, HasBeenReceivedCapability (IM i))
    (Hbo : forall i : index, HasBeenObservedCapability (IM i)
      := fun i => HasBeenObservedCapability_from_sent_received (IM i))
    {index_listing : list index}
    (finite_index : Listing index_listing)
    (i : index)
    (s : vstate (IM i))
    (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm (IM i)) s)
    (m : message)
    : composite_has_been_observed IM Hbo (lift_to_composite_state IM i s) m <-> has_been_observed (HasBeenObservedCapability := Hbo i) (IM i) s m.
  Proof.
    pose (free_composite_vlsm IM) as Free.
    pose (free_composite_HasBeenObservedCapability IM finite_index Hbo) as Free_Hbo.
    pose (free_composite_HasBeenReceivedCapability IM finite_index Hbr) as Free_Hbr.
    pose (free_composite_HasBeenSentCapability IM finite_index Hbs) as Free_Hbs.
    assert
      (Hlift_s : valid_state_prop (pre_loaded_with_all_messages_vlsm Free) (lift_to_composite_state IM i s)).
    { revert Hs.  apply valid_state_preloaded_composite_free_lift. }
    split; intros Hobs.
    - apply (proper_observed (Hbo i)); [assumption|].
      intros is tr Htr.
      apply (proper_observed Free_Hbo) in Hobs
      ; [|assumption].
      apply (VLSM_full_projection_finite_valid_trace_init_to (lift_to_composite_preloaded_vlsm_full_projection IM i)) in Htr as Hpre_tr.
      specialize (Hobs _ _ Hpre_tr).
      apply Exists_exists.
      apply Exists_exists in Hobs.
      destruct Hobs as [composite_item [Hcomposite_item Hx]].
      apply elem_of_list_In in Hcomposite_item.
      apply in_map_iff in Hcomposite_item.
      destruct Hcomposite_item as [item [Hcomposite_item Hitem]].
      exists item.
      apply elem_of_list_In in Hitem.
      split; [assumption|].
      subst composite_item.
      destruct item. simpl in *.
      assumption.
    - apply (proper_observed Free_Hbo); [assumption|].
      apply has_been_observed_consistency; [assumption|assumption|].
      apply (proper_observed (Hbo i)) in Hobs ; [|assumption].
      apply has_been_observed_consistency in Hobs; [|apply Hbo|assumption].
      destruct Hobs as [is [tr [Htr Hobs]]].
      apply (VLSM_full_projection_finite_valid_trace_init_to (lift_to_composite_preloaded_vlsm_full_projection IM i)) in Htr as Hpre_tr.
      eexists. eexists. exists Hpre_tr.
      apply Exists_exists.
      apply Exists_exists in Hobs.
      destruct Hobs as [item [Hitem Hx]].
      exists (lift_to_composite_transition_item IM i item).
      split; [|destruct item; assumption].
      apply elem_of_list_In.
      apply in_map_iff. exists item.
      apply elem_of_list_In in Hitem.
      split; [|assumption].
      destruct item; reflexivity.
  Qed.

Section cannot_resend_message.
Context
  {message : Type}
  `{EqDecision message}
  (X : VLSM message)
  (PreX := pre_loaded_with_all_messages_vlsm X)
  {Hbs : HasBeenSentCapability X}
  {Hbr : HasBeenReceivedCapability X}
  .

Definition state_received_not_sent (s : state) (m : message) : Prop :=
  has_been_received X s m /\ ~ has_been_sent X s m.

Lemma state_received_not_sent_trace_iff
  (m : message)
  (s : state)
  (is : state)
  (tr : list transition_item)
  (Htr : finite_valid_trace_init_to PreX is s tr)
  : state_received_not_sent s m <-> trace_received_not_sent_before_or_after tr m.
Proof.
  assert (Hs : valid_state_prop PreX s).
  { apply proj1 in Htr.  apply valid_trace_last_pstate in Htr.
    assumption.
  }
  split; intros [Hbrm Hnbsm].
  - apply proper_received in Hbrm; [|assumption].
    specialize (Hbrm is tr Htr).
    split; [assumption|].
    intro Hbsm. elim Hnbsm.
    apply proper_sent; [assumption|].
    apply has_been_sent_consistency; [assumption| assumption|].
    exists is, tr, Htr. assumption.
  - split.
    + apply proper_received; [assumption|].
      apply has_been_received_consistency; [assumption| assumption|].
      exists is, tr, Htr. assumption.
    + intro Hbsm. elim Hnbsm.
      apply proper_sent in Hbsm; [|assumption].
      spec Hbsm is tr Htr. assumption.
Qed.

Definition state_received_not_sent_invariant
  (s : state)
  (P : message -> Prop)
  : Prop
  := forall m, state_received_not_sent s m -> P m.

Lemma state_received_not_sent_invariant_trace_iff
  (P : message -> Prop)
  (s : state)
  (is : state)
  (tr : list transition_item)
  (Htr : finite_valid_trace_init_to PreX is s tr)
  : state_received_not_sent_invariant s P <->
    trace_received_not_sent_before_or_after_invariant tr P.
Proof.
  split; intros Hinv m Hm
  ; apply Hinv
  ; apply (state_received_not_sent_trace_iff m s is tr Htr)
  ; assumption.
Qed.

(**
A sent message cannot have been previously sent or received.
*)
Definition cannot_resend_message_stepwise_prop : Prop :=
  forall l s oim s' m,
    input_valid_transition (pre_loaded_with_all_messages_vlsm X) l (s,oim) (s',Some m) ->
    ~has_been_sent X s m /\ ~has_been_received X s' m.

Lemma cannot_resend_received_message_in_future
  (Hno_resend : cannot_resend_message_stepwise_prop)
  (s1 s2 : state)
  (Hfuture : in_futures PreX s1 s2)
  : forall m : message,
    state_received_not_sent s1 m -> state_received_not_sent s2 m.
Proof.
  intros m Hm.
  destruct Hfuture as [tr2 Htr2].
  induction Htr2.
  - assumption.
  - apply IHHtr2;clear IHHtr2.
    specialize (has_been_received_step_update Ht m) as Hrupd.
    specialize (has_been_sent_step_update Ht m) as Hmupd.
    destruct Hm as [Hr Hs].
    eapply or_intror in Hr; apply Hrupd in Hr.
    split.
    + assumption.
    + intros [->|]%Hmupd;[|apply Hs;assumption].
      apply Hno_resend in Ht as [_ []].
      assumption.
Qed.

  Context
    (Hno_resend : cannot_resend_message_stepwise_prop).

  Lemma input_valid_transition_received_not_resent l s m s' om'
    (Ht : input_valid_transition (pre_loaded_with_all_messages_vlsm X) l (s,Some m) (s', om'))
    : om' <> Some m.
  Proof.
    destruct om' as [m'|]; [|congruence].
    intro Heq. inversion Heq. subst m'. clear Heq.
    destruct (Hno_resend _ _ _ _ _ Ht) as [_ Hnbr_m].
    elim Hnbr_m. clear Hnbr_m.
    apply exists_right_finite_trace_from in Ht.
    destruct Ht as [is [tr [Htr Hs]]].
    apply proj1 in Htr as Hlst. apply finite_valid_trace_from_to_last_pstate in Hlst.
    apply proper_received; [assumption|].
    apply has_been_received_consistency; [assumption|assumption|].
    exists _,_,Htr.
    apply Exists_app. right. apply Exists_cons. left. reflexivity.
  Qed.

  Lemma lift_preloaded_trace_to_seeded
    (P : message -> Prop)
    (tr: list transition_item)
    (Htrm: trace_received_not_sent_before_or_after_invariant tr P)
    (is: state)
    (Htr: finite_valid_trace PreX is tr)
    : finite_valid_trace (pre_loaded_vlsm X P) is tr.
  Proof.
    unfold trace_received_not_sent_before_or_after_invariant in Htrm.
    split; [|apply Htr].
    induction Htr using finite_valid_trace_rev_ind; intros.
    - rapply @finite_valid_trace_from_empty.
      apply initial_state_is_valid. assumption.
    - assert (trace_received_not_sent_before_or_after_invariant tr P) as Htrm'.
      { intros m [Hrecv Hsend]. apply (Htrm m);clear Htrm.
        split;[apply Exists_app;left;assumption|].
        contradict Hsend.
        unfold trace_has_message in Hsend.
        rewrite Exists_app, Exists_cons, Exists_nil in Hsend.
        simpl in Hsend.
        cut (oom <> Some m);[tauto|clear Hsend].
        intros ->.
        cut (has_been_received X sf m);[apply (Hno_resend _ _ _ _ _ Hx)|].
        apply (has_been_received_step_update Hx);right.
        erewrite oracle_partial_trace_update.
        - left;exact Hrecv.
        - apply has_been_received_stepwise_from_trace.
        - apply valid_trace_add_default_last. apply Htr.
      }
      specialize (IHHtr Htrm').
      apply (extend_right_finite_trace_from _ IHHtr).
      repeat split;try apply Hx;
      [apply finite_valid_trace_last_pstate;assumption|].
      destruct iom as [m|];[|apply option_valid_message_None].
      (* If m was sent during tr, it is valid because it was
         produced in a valid (by IHHtr) trace.
         If m was not sent during tr,
       *)
      assert (Decision (trace_has_message (field_selector output) m tr)) as [Hsent|Hnot_sent].
      apply (@Exists_dec _). intros. apply decide_eq.
      + exact (valid_trace_output_is_valid _ _ _ IHHtr _ Hsent).
      + apply initial_message_is_valid.
        right. apply Htrm.
        split.
        * apply Exists_app. right;apply Exists_cons. left;reflexivity.
        * intro Hsent;destruct Hnot_sent.
          unfold trace_has_message in Hsent.
          rewrite Exists_app, Exists_cons, Exists_nil in Hsent.
          destruct Hsent as [Hsent|[[=->]|[]]];[assumption|exfalso].
          apply Hno_resend in Hx as Hx'.
          apply (proj2 Hx');clear Hx'.
          rewrite (has_been_received_step_update Hx).
          left;reflexivity.
  Qed.

  Lemma lift_preloaded_state_to_seeded
    (P : message -> Prop)
    (s: state)
    (Hequiv_s: state_received_not_sent_invariant s P)
    (Hs: valid_state_prop PreX s)
    : valid_state_prop (pre_loaded_vlsm X P) s.
  Proof.
    apply valid_state_has_trace in Hs as Htr.
    destruct Htr as [is [tr Htr]].
    specialize (lift_preloaded_trace_to_seeded P tr) as Hlift.
    spec Hlift.
    { revert Hequiv_s.
      apply state_received_not_sent_invariant_trace_iff with is; assumption.
    }
    specialize (Hlift _ (valid_trace_forget_last Htr)).
    apply proj1 in Hlift.
    apply finite_valid_trace_last_pstate in Hlift.
    rewrite <- (valid_trace_get_last Htr). assumption.
  Qed.

  Lemma lift_generated_to_seeded
    (P : message -> Prop)
    (s : state)
    (Hequiv_s: state_received_not_sent_invariant s P)
    (m : message)
    (Hgen : can_produce PreX s m)
    : can_produce (pre_loaded_vlsm X P) s m.
  Proof.
    apply non_empty_valid_trace_from_can_produce.
    apply non_empty_valid_trace_from_can_produce in Hgen.
    destruct Hgen as [is [tr [item [Htr Hgen]]]].
    exists is, tr, item. split; [|assumption].
    specialize (lift_preloaded_trace_to_seeded P tr) as Hlift.
    spec Hlift.
    { revert Hequiv_s.
      apply state_received_not_sent_invariant_trace_iff with is.
      apply valid_trace_add_last. assumption.
      apply last_error_destination_last.
      destruct Hgen as [Hlst [Hs _]]. rewrite Hlst. subst. reflexivity.
    }
    apply Hlift. assumption.
  Qed.

End cannot_resend_message.

Section has_been_sent_irrelevance.

(**
  As we have several ways of obtaining the 'has_been_sent' property, we need to
  sometime show that they are equivalent.
*)

  Context
    {message : Type}
    (X : VLSM message)
    (Hbs1 : HasBeenSentCapability X)
    (Hbs2 : HasBeenSentCapability X)
    (has_been_sent1 := @has_been_sent _ X Hbs1)
    (has_been_sent2 := @has_been_sent _ X Hbs2)
    .

  Lemma has_been_sent_irrelevance
    (s : state)
    (m : message)
    (Hs : valid_state_prop (pre_loaded_with_all_messages_vlsm X) s)
    : has_been_sent1 s m -> has_been_sent2 s m.
  Proof.
    intro H.
    apply proper_sent in H; [|assumption].
    apply proper_sent; [assumption|].
    assumption.
  Qed.

End has_been_sent_irrelevance.

Section all_traces_to_valid_state_are_valid.

Context
  {message : Type}
  {index : Type}
  {IndEqDec : EqDecision index}
  (IM : index -> VLSM message)
  (constraint : composite_label IM -> composite_state IM * option message -> Prop)
  (X := composite_vlsm IM constraint)
  (PreX := pre_loaded_with_all_messages_vlsm X)
  (has_been_received_capabilities : forall i : index, (HasBeenReceivedCapability (IM i)))
  {index_listing : list index}
  (finite_index : Listing index_listing)
  (X_HasBeenReceivedCapability : HasBeenReceivedCapability X
    := composite_HasBeenReceivedCapability IM finite_index has_been_received_capabilities constraint
  )
  .

Existing Instance X_HasBeenReceivedCapability.

(**
Under [HasBeenReceivedCapability] assumptions, and given the fact that
any valid state <<s>> has a valid trace leading to it,
in which all (received) messages are valid, it follows that
any message which [has_been_received] for state <<s>> is valid.

Hence, given any pre_loaded trace leading to <<s>>, all messages received
within it must be valid, thus the trace itself is valid.
*)
Lemma pre_traces_with_valid_inputs_are_valid is s tr
  (Htr : finite_valid_trace_init_to PreX is s tr)
  (Hobs : forall m,
    trace_has_message (field_selector input) m tr ->
    valid_message_prop X m
  )
  : finite_valid_trace_init_to X is s tr.
Proof.
  revert s Htr Hobs.
  induction tr using rev_ind; intros; split
  ; [|apply Htr| | apply Htr]
  ; destruct Htr as [Htr Hinit].
  - inversion Htr. subst.
    apply (finite_valid_trace_from_to_empty X).
    apply initial_state_is_valid. assumption.
  - apply finite_valid_trace_from_to_last in Htr as Hlst.
    apply finite_valid_trace_from_to_app_split in Htr.
    destruct Htr as [Htr Hx].
    specialize (IHtr _ (conj Htr Hinit)).
    spec IHtr.
    { intros. apply Hobs.
      apply trace_has_message_prefix. assumption.
    }
    apply proj1, finite_valid_trace_from_to_forget_last in IHtr.
    apply finite_valid_trace_from_add_last; [|assumption].
    inversion Hx. subst f tl s'.
    apply (extend_right_finite_trace_from X)
    ; [assumption|].
    destruct Ht as [[_ [_ [Hv Hc]]] Ht].
    apply finite_valid_trace_last_pstate in IHtr as Hplst.
    repeat split; try assumption.
    destruct iom as [m|]; [|apply option_valid_message_None].
    apply option_valid_message_Some.
    apply Hobs.
    apply Exists_app. right.
    apply Exists_cons. left.
    subst. reflexivity.
Qed.

Lemma all_pre_traces_to_valid_state_are_valid
  s
  (Hs : valid_state_prop X s)
  is tr
  (Htr : finite_valid_trace_init_to PreX is s tr)
  : finite_valid_trace_init_to X is s tr.
Proof.
  apply pre_traces_with_valid_inputs_are_valid in Htr; [assumption|].
  apply valid_trace_last_pstate in Htr as Hspre.
  intros.
  apply
    (composite_received_valid IM finite_index
      has_been_received_capabilities _ _ Hs
    ).
  specialize (proper_received _ s Hspre m) as Hproper.
  apply proj2 in Hproper. apply Hproper.
  apply has_been_received_consistency; [assumption|assumption|].
  exists is, tr, Htr. assumption.
Qed.

End all_traces_to_valid_state_are_valid.

Section has_been_received_in_state.

  Context
    {message : Type}
    (X : VLSM message)
    (Hbr : HasBeenReceivedCapability X)
  .

  Lemma has_been_received_in_state s1 m:
    valid_state_prop X s1 ->
    has_been_received X s1 m ->
    exists (s0 : state) (item : transition_item) (tr : list transition_item),
      input item = Some m /\
      finite_valid_trace_from_to X s0 s1 (item :: tr).
  Proof.
    intros Hpsp Hhbr.
    pose proof (Hetr := valid_state_has_trace _ _ Hpsp).
    destruct Hetr as [ist [tr Hetr]].
    apply proper_received in Hhbr.
    2: { apply pre_loaded_with_all_messages_valid_state_prop.
         apply Hpsp.
    }

    unfold selected_message_exists_in_all_preloaded_traces in Hhbr.
    unfold specialized_selected_message_exists_in_all_traces in Hhbr.
    specialize (Hhbr ist tr).
    unfold finite_valid_trace_init_to in Hhbr.
    unfold finite_valid_trace_init_to in Hetr.
    destruct Hetr as [Hfptf Hisp].
    pose proof (Hfptf' := preloaded_weaken_finite_valid_trace_from_to _ _ _ _ Hfptf).
    specialize (Hhbr (conj Hfptf' Hisp)).
    clear Hfptf'.

    unfold trace_has_message in Hhbr. unfold field_selector in Hhbr.
    apply Exists_exists in Hhbr.
    destruct Hhbr as [tritem [Htritemin Hintritem]].
    apply elem_of_list_split in Htritemin.
    destruct Htritemin as [l1 [l2 Heqtr]].
    rewrite Heqtr in Hfptf.
    apply (finite_valid_trace_from_to_app_split X) in Hfptf.
    destruct Hfptf as [Htr1 Htr2].
    destruct tritem eqn:Heqtritem.
    simpl in Hintritem. subst input.
    eexists. eexists. eexists.
    split.
    2: { apply  Htr2. }
    reflexivity.
  Qed.

  Lemma has_been_received_in_state_preloaded s1 m:
    valid_state_prop (pre_loaded_with_all_messages_vlsm X) s1 ->
    has_been_received X s1 m ->
    exists (s0 : state) (item : transition_item) (tr : list transition_item),
      input item = Some m /\
      finite_valid_trace_from_to (pre_loaded_with_all_messages_vlsm X) s0 s1 (item :: tr).
  Proof.
    intros Hpsp Hhbr.
    pose proof (Hetr := valid_state_has_trace _ _ Hpsp).
    destruct Hetr as [ist [tr Hetr]].
    apply proper_received in Hhbr.
    2: { apply Hpsp. }

    unfold selected_message_exists_in_all_preloaded_traces in Hhbr.
    unfold specialized_selected_message_exists_in_all_traces in Hhbr.
    specialize (Hhbr ist tr).
    unfold finite_valid_trace_init_to in Hhbr.
    unfold finite_valid_trace_init_to in Hetr.
    destruct Hetr as [Hfptf Hisp].
    specialize (Hhbr (conj Hfptf Hisp)).

    unfold trace_has_message in Hhbr. unfold field_selector in Hhbr.
    apply Exists_exists in Hhbr.
    destruct Hhbr as [tritem [Htritemin Hintritem]].
    apply elem_of_list_split in Htritemin.
    destruct Htritemin as [l1 [l2 Heqtr]].
    rewrite Heqtr in Hfptf.
    apply (finite_valid_trace_from_to_app_split (pre_loaded_with_all_messages_vlsm X)) in Hfptf.
    destruct Hfptf as [Htr1 Htr2].
    destruct tritem eqn:Heqtritem.
    simpl in Hintritem. subst input.
    eexists. eexists. eexists.
    split.
    2: { apply  Htr2. }
    reflexivity.
  Qed.

End has_been_received_in_state.
