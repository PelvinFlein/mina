open Core_kernel

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io]

    module Snarkable : functor (Impl : Snark_intf.S) ->
      Impl.Snarkable.Bits.S
  end

  module Params : sig
    type t = curve array

    val random : max_input_length:int -> t
  end

  module State : sig
    type t

    val create : Params.t ->  t

    val update : t -> Bigstring.t -> unit

    val digest : t -> Digest.t
  end
end

module Make
  : functor
    (Field : Camlsnark.Field_intf.S)
    (Bigint : Camlsnark.Bigint_intf.S with type field := Field.t)
    (Curve : Camlsnark.Curves.Edwards.Basic.S with type field := Field.t) ->
    S with type curve := Curve.t

module Main : sig
  module Curve : sig
    include Camlsnark.Curves.Edwards.Basic.S
      with type field := Snark_params.Main.Field.t

    module Scalar : functor (Impl : Camlsnark.Snark_intf.S) ->sig
      type var = Impl.Boolean.var list
      type value = bool list
      val length : int
      val spec : (var, value) Impl.Var_spec.t
      val assert_equal : var -> var -> (unit, _) Impl.Checked.t
    end
end

  include S with type curve := Curve.t

  val params : Params.t
end

val hash : Bigstring.t -> Digest.t

val zero_hash : Digest.t
