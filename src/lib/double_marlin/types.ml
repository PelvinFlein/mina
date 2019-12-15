module Dlog_based = struct
  module Proof_state = struct
    module Deferred_values = struct
      (* For each evaluation point beta_i, just expose the value of
        \sum_j xi^i f_j(beta_i). The next person can exists in
        the actualy values f_j(beta_i) and check them against that
        value and xi.
      *)
      module Marlin = struct
        type ('challenge, 'fp) t =
          { sigma_2: 'fp
          ; sigma_3: 'fp
          ; alpha: 'challenge (* 128 bits *)
          ; eta_a: 'challenge (* 128 bits *)
          ; eta_b: 'challenge (* 128 bits *)
          ; eta_c: 'challenge (* 128 bits *)
          ; beta_1: 'challenge (* 128 bits *)
          ; beta_2: 'challenge (* 128 bits *)
          ; beta_3: 'challenge (* 128 bits *) }

        let map_challenges
            { sigma_2
            ; sigma_3
            ; alpha
            ; eta_a
            ; eta_b
            ; eta_c
            ; beta_1
            ; beta_2
            ; beta_3 } ~f =
          { sigma_2
          ; sigma_3
          ; alpha= f alpha
          ; eta_a= f eta_a
          ; eta_b= f eta_b
          ; eta_c= f eta_c
          ; beta_1= f beta_1
          ; beta_2= f beta_2
          ; beta_3= f beta_3 }

        open Snarky.H_list

        let to_hlist
            { sigma_2
            ; sigma_3
            ; alpha
            ; eta_a
            ; eta_b
            ; eta_c
            ; beta_1
            ; beta_2
            ; beta_3 } =
          [sigma_2; sigma_3; alpha; eta_a; eta_b; eta_c; beta_1; beta_2; beta_3]

        let of_hlist
            ([ sigma_2
             ; sigma_3
             ; alpha
             ; eta_a
             ; eta_b
             ; eta_c
             ; beta_1
             ; beta_2
             ; beta_3 ] :
              (unit, _) t) =
          {sigma_2; sigma_3; alpha; eta_a; eta_b; eta_c; beta_1; beta_2; beta_3}

        let typ chal fp =
          Snarky.Typ.of_hlistable
            [fp; fp; chal; chal; chal; chal; chal; chal; chal]
            ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
            ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
      end

      type ('challenge, 'fp) t =
        { xi: 'challenge
        ; r: 'challenge
        ; r_xi_sum: 'fp
        ; marlin: ('challenge, 'fp) Marlin.t }

      let map_challenges {xi; r; r_xi_sum; marlin} ~f =
        {xi= f xi; r= f r; r_xi_sum; marlin= Marlin.map_challenges marlin ~f}

      open Snarky.H_list

      let to_hlist {xi; r; r_xi_sum; marlin} = [xi; r; r_xi_sum; marlin]

      let of_hlist ([xi; r; r_xi_sum; marlin] : (unit, _) t) =
        {xi; r; r_xi_sum; marlin}

      let typ chal fp =
        Snarky.Typ.of_hlistable
          [chal; chal; fp; Marlin.typ chal fp]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    end

    module Me_only = struct
      type 'g1 t =
        { pairing_marlin_index: 'g1 Abc.t Matrix_evals.t
        ; pairing_marlin_acc: 'g1 Pairing_marlin_types.Accumulator.t }

      open Snarky.H_list

      let to_hlist {pairing_marlin_index; pairing_marlin_acc} =
        [pairing_marlin_index; pairing_marlin_acc]

      let of_hlist ([pairing_marlin_index; pairing_marlin_acc] : (unit, _) t) =
        {pairing_marlin_index; pairing_marlin_acc}

      let typ g1 =
        Snarky.Typ.of_hlistable
          [ g1 |> Abc.typ |> Matrix_evals.typ
          ; Pairing_marlin_types.Accumulator.typ g1 ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    end

    type ('challenge, 'fp, 'me_only, 'digest) t =
      { deferred_values: ('challenge, 'fp) Deferred_values.t
      ; sponge_digest_before_evaluations: 'digest
            (* Not needed by other proof system *)
      ; me_only: 'me_only }

    open Snarky.H_list

    let to_hlist {deferred_values; sponge_digest_before_evaluations; me_only} =
      [deferred_values; sponge_digest_before_evaluations; me_only]

    let of_hlist
        ([deferred_values; sponge_digest_before_evaluations; me_only] :
          (unit, _) t) =
      {deferred_values; sponge_digest_before_evaluations; me_only}

    let typ chal fp me_only digest =
      Snarky.Typ.of_hlistable
        [Deferred_values.typ chal fp; digest; me_only]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Pass_through = struct
    type ('g, 's) t =
      {app_state: 's; dlog_marlin_index: 'g Abc.t Matrix_evals.t; sg: 'g}

    open Snarky.H_list

    let to_hlist {app_state; dlog_marlin_index; sg} =
      [app_state; dlog_marlin_index; sg]

    let of_hlist ([app_state; dlog_marlin_index; sg] : (unit, _) t) =
      {app_state; dlog_marlin_index; sg}

    let typ g s =
      Snarky.Typ.of_hlistable
        [s; Matrix_evals.typ (Abc.typ g); g]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Statement = struct
    type ('challenge, 'fp, 'me_only, 'digest, 'pass_through) t =
      { proof_state: ('challenge, 'fp, 'me_only, 'digest) Proof_state.t
      ; pass_through: 'pass_through }

    (*
    let reader ~fp ~challenge ()  =
      let deferred_values () =
        let marlin () =
          let sigma_2 = fp () in
          let sigma_3 = fp () in
          let alpha = challenge () in
          let eta_a = challenge () in
          let eta_b = challenge () in
          let eta_c = challenge () in
          let beta_1 = challenge () in
          let beta_2 = challenge () in
          let beta_3 = challenge () in
          { Proof_state.Deferred_values.Marlin.sigma_2
          ; sigma_3
          ; alpha
          ; eta_a
          ; eta_b
          ; eta_c
          ; beta_1
          ; beta_2
          ; beta_3
          }
        in
        let xi = challenge () in
        let 
        let marlin = marlin () in
      in

*)
    (* An isomorphism with bool list * field list.
    *)
    let to_data
        { proof_state=
            { deferred_values=
                { xi
                ; r
                ; r_xi_sum
                ; marlin=
                    { sigma_2
                    ; sigma_3
                    ; alpha
                    ; eta_a
                    ; eta_b
                    ; eta_c
                    ; beta_1
                    ; beta_2
                    ; beta_3 } }
            ; sponge_digest_before_evaluations
            ; me_only }
        ; pass_through } =
      let open Vector in
      let fp = [sigma_2; sigma_3; r_xi_sum] in
      let challenge =
        [xi; r; alpha; eta_a; eta_b; eta_c; beta_1; beta_2; beta_3]
      in
      let digest = [sponge_digest_before_evaluations; me_only; pass_through] in
      (fp, challenge, digest)

    let of_data (fp, challenge, digest) =
      let open Vector in
      let [sigma_2; sigma_3; r_xi_sum] = fp in
      let [xi; r; alpha; eta_a; eta_b; eta_c; beta_1; beta_2; beta_3] =
        challenge
      in
      let [sponge_digest_before_evaluations; me_only; pass_through] = digest in
      { proof_state=
          { deferred_values=
              { xi
              ; r
              ; r_xi_sum
              ; marlin=
                  { sigma_2
                  ; sigma_3
                  ; alpha
                  ; eta_a
                  ; eta_b
                  ; eta_c
                  ; beta_1
                  ; beta_2
                  ; beta_3 } }
          ; sponge_digest_before_evaluations
          ; me_only }
      ; pass_through }
  end
end

module Pairing_based = struct
  module Marlin_polys = Vector.Nat.N20

  module Bulletproof_challenge = struct
    type ('challenge, 'bool) t = {prechallenge: 'challenge; is_square: 'bool}

    open Snarky.H_list

    let to_hlist {prechallenge; is_square} = [prechallenge; is_square]

    let of_hlist ([prechallenge; is_square] : (unit, _) t) =
      {prechallenge; is_square}

    let typ chal bool =
      Snarky.Typ.of_hlistable [chal; bool] ~var_to_hlist:to_hlist
        ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Openings = struct
    module Evaluations = struct
      module By_point = struct
        type 'fq t = {beta_1: 'fq; beta_2: 'fq; beta_3: 'fq; g_challenge: 'fq}
      end

      type 'fq t = ('fq By_point.t, Marlin_polys.n Vector.s) Vector.t
    end

    module Bulletproof = struct
      type ('fq, 'g) t =
        {gammas: ('g * 'g) array; z_1: 'fq; z_2: 'fq; beta: 'g; delta: 'g}

      open Snarky.H_list

      let to_hlist {gammas; z_1; z_2; beta; delta} =
        [gammas; z_1; z_2; beta; delta]

      let of_hlist ([gammas; z_1; z_2; beta; delta] : (unit, _) t) =
        {gammas; z_1; z_2; beta; delta}

      let typ fq g ~length =
        let open Snarky.Typ in
        of_hlistable
          [array ~length (g * g); fq; fq; g; g]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

      module Advice = struct
        (* This is data that can be computed in linear time from the above plus the statement.
        
          It doesn't need to be sent on the wire, but it does need to be provided to the verifier
        *)
        type ('fq, 'g) t = {sg: 'g; a_hat: 'fq}

        open Snarky.H_list

        let to_hlist {sg; a_hat} = [sg; a_hat]

        let of_hlist ([sg; a_hat] : (unit, _) t) = {sg; a_hat}

        let typ fq g =
          let open Snarky.Typ in
          of_hlistable [fq; g] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
            ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
      end
    end

    type ('fq, 'g) t =
      {evaluations: 'fq Evaluations.t; proof: ('fq, 'g) Bulletproof.t}

    (* TODO
    open Snarky.H_list
    let to_hlist {evaluations; proof} = [evaluations; proof]
    let of_hlist ([evaluations; proof] : (unit, _) t) = {evaluations; proof}

    let typ fq g ~length =
      let open Snarky.Typ in
      of_hlistable
        [ B
        ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
*)
  end

  module Proof_state = struct
    module Deferred_values = struct
      module Marlin = Dlog_based.Proof_state.Deferred_values.Marlin

      type ('challenge, 'fq, 'bool) t =
        { marlin: ('challenge, 'fq) Marlin.t
        ; combined_inner_product: 'fq
        ; xi: 'challenge (* 128 bits *)
        ; r: 'challenge (* 128 bits *)
        ; bulletproof_challenges:
            ('challenge, 'bool) Bulletproof_challenge.t array
        ; a_hat: 'fq }

      open Snarky.H_list

      let to_hlist
          {marlin; combined_inner_product; xi; r; bulletproof_challenges; a_hat}
          =
        [marlin; combined_inner_product; xi; r; bulletproof_challenges; a_hat]

      let of_hlist
          ([ marlin
           ; combined_inner_product
           ; xi
           ; r
           ; bulletproof_challenges
           ; a_hat ] :
            (unit, _) t) =
        {marlin; combined_inner_product; xi; r; bulletproof_challenges; a_hat}

      let typ chal fq bool ~length =
        Snarky.Typ.of_hlistable
          [ Marlin.typ chal fq
          ; fq
          ; chal
          ; chal
          ; Snarky.Typ.array (Bulletproof_challenge.typ chal bool) ~length
          ; fq ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    end

    module Pass_through = Dlog_based.Proof_state.Me_only
    module Me_only = Dlog_based.Pass_through

    type ('challenge, 'fq, 'bool, 'me_only, 'digest) t =
      { deferred_values: ('challenge, 'fq, 'bool) Deferred_values.t
      ; sponge_digest_before_evaluations: 'digest
      ; me_only: 'me_only }

    open Snarky.H_list

    let of_hlist
        ([deferred_values; sponge_digest_before_evaluations; me_only] :
          (unit, _) t) =
      {deferred_values; sponge_digest_before_evaluations; me_only}

    let to_hlist {deferred_values; sponge_digest_before_evaluations; me_only} =
      [deferred_values; sponge_digest_before_evaluations; me_only]

    let typ challenge fq bool me_only digest ~length =
      Snarky.Typ.of_hlistable
        [Deferred_values.typ challenge fq bool ~length; digest; me_only]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  module Statement = struct
    type ('challenge, 'fq, 'bool, 'me_only, 'pass_through, 'digest, 's) t =
      { proof_state: ('challenge, 'fq, 'bool, 'me_only, 'digest) Proof_state.t
      ; pass_through: 'pass_through }

    let to_data
        { proof_state=
            { deferred_values=
                { xi
                ; r
                ; bulletproof_challenges
                ; a_hat
                ; combined_inner_product
                ; marlin=
                    { sigma_2
                    ; sigma_3
                    ; alpha
                    ; eta_a
                    ; eta_b
                    ; eta_c
                    ; beta_1
                    ; beta_2
                    ; beta_3 } }
            ; sponge_digest_before_evaluations
            ; me_only }
        ; pass_through } =
      let open Vector in
      let fq = [sigma_2; sigma_3; combined_inner_product; a_hat] in
      let challenge =
        [alpha; eta_a; eta_b; eta_c; beta_1; beta_2; beta_3; xi; r]
      in
      let digest = [sponge_digest_before_evaluations; me_only; pass_through] in
      (fq, digest, challenge, bulletproof_challenges)

    let of_data (fq, digest, challenge, bulletproof_challenges) =
      let open Vector in
      let [sigma_2; sigma_3; combined_inner_product; a_hat] = fq in
      let [alpha; eta_a; eta_b; eta_c; beta_1; beta_2; beta_3; xi; r] =
        challenge
      in
      let [sponge_digest_before_evaluations; me_only; pass_through] = digest in
      { proof_state=
          { deferred_values=
              { xi
              ; r
              ; bulletproof_challenges
              ; a_hat
              ; combined_inner_product
              ; marlin=
                  { sigma_2
                  ; sigma_3
                  ; alpha
                  ; eta_a
                  ; eta_b
                  ; eta_c
                  ; beta_1
                  ; beta_2
                  ; beta_3 } }
          ; sponge_digest_before_evaluations
          ; me_only }
      ; pass_through }
  end
end