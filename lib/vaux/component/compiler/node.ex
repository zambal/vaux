defmodule Vaux.Component.Compiler.Node do
  @moduledoc false

  alias __MODULE__

  @dialyzer {:no_return, raise_error: 2}
  @compile {:inline, raise_error: 2}

  @directive_attrs ~w(:for :cond :if :else :case :clause :bind :let :keep)

  @void_elements ~w(area base br col embed hr img input link meta source track wbr)

  @type directive :: :":for" | :":cond" | :":if" | :":else" | :":case" | :":clause"
  @type attrs :: [{String.t(), String.t() | Macro.t()}]
  @type line :: non_neg_integer()
  @type content :: {:characters, line, String.t()} | {:expr, line, String.t()}
  @type node_type :: :element | :component | :slot | :content

  @type t :: %Node{
          tag: String.t(),
          env: Macro.Env.t(),
          line: non_neg_integer(),
          dir: nil | {directive(), String.t()},
          binding: Macro.t() | nil,
          attrs: attrs(),
          global_attrs: boolean(),
          content: [t()] | String.t(),
          parent: t(),
          keep: boolean(),
          type: node_type()
        }

  defstruct tag: nil,
            env: "nofile",
            line: 0,
            dir: nil,
            binding: nil,
            attrs: [],
            global_attrs: false,
            content: [],
            parent: nil,
            keep: true,
            type: :element

  def new(tag, attrs, parent, line, content \\ []) do
    type = get_type_from_tag(tag)

    keep = if type == :slot, do: false, else: true

    {parent, {_file, offset} = env} =
      case parent do
        {_file, _line} = env -> {nil, env}
        %Node{env: env} = node -> {node, env}
      end

    node = %Node{tag: tag, parent: parent, env: env, line: offset + line, content: content, keep: keep, type: type}
    add_attributes(node, attrs)
  end

  def add(%Node{content: acc} = node, %Node{} = content) do
    %{node | content: [%{content | parent: nil} | acc]}
  end

  defp add_attributes(node, attrs) do
    Enum.reduce(attrs, node, &add_attribute(&2, &1))
  end

  defp add_attribute(node, {_, _, dir, expr_string})
       when dir in @directive_attrs do
    put_directive(node, dir, expr_string)
  end

  defp add_attribute(%Node{tag: "template", type: :slot} = node, {_, _, "#" <> key, _}) do
    %{node | attrs: [try_to_existing_atom(key, node, "no slot :#{key} defined")]}
  end

  defp add_attribute(%Node{tag: "slot", type: :slot} = node, {_, _, "#" <> key, _}) do
    %{node | attrs: [try_to_existing_atom(key, node, "no slot :#{key} defined")]}
  end

  defp add_attribute(%Node{type: :slot} = node, _attr) do
    node
  end

  defp add_attribute(%Node{attrs: attrs} = node, {_, _, name, value}) do
    %{node | attrs: [{name, value} | attrs]}
  end

  defp put_directive(%Node{} = node, ":keep", _expr_string) do
    %{node | keep: true}
  end

  defp put_directive(%Node{} = node, binding, expr_string) when binding in ~w(:bind :let) do
    expr_string = normalize_directive(expr_string, binding, node)
    binding = {try_to_existing_atom(binding, node, "unexpected error parsing #{inspect(binding)}"), expr_string}
    %{node | binding: binding}
  end

  defp put_directive(%Node{dir: nil} = node, dir, expr_string) do
    expr_string = normalize_directive(expr_string, dir, node)
    %{node | dir: {try_to_existing_atom(dir, node, "invalid directive #{dir}"), expr_string}}
  end

  defp put_directive(node, _op, _expr_string) do
    raise_error(node, "Vaux currently supports only a single directive per element")
  end

  defp normalize_directive(expr_string, dir, node) do
    case expr_string do
      {:expr, string} ->
        string

      "" when dir == ":else" ->
        ""

      string when is_binary(string) and dir == ":clause" ->
        "\"" <> string <> "\""

      _ ->
        raise_error(node, "Vaux directives require an expression")
    end
  end

  def get_type_from_tag(:characters), do: :content
  def get_type_from_tag(:expr), do: :content

  def get_type_from_tag("template"), do: :slot
  def get_type_from_tag("slot"), do: :slot

  def get_type_from_tag(tag) do
    if String.match?(tag, ~r/^[[:upper:]].*$/u),
      do: :component,
      else: :element
  end

  defp try_to_existing_atom(string, node, error_text) do
    try do
      String.to_existing_atom(string)
    rescue
      ArgumentError -> raise_error(node, error_text)
    end
  end

  defp raise_error(%Node{env: {file, _}, line: line}, description) do
    raise Vaux.CompileError, file: file, line: line, description: description
  end

  def void_element?(tag) when tag in @void_elements, do: true
  def void_element?(_tag), do: false

  # Extracted from https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes
  global_attributes = ~w(
    onabort
    onautocomplete
    onautocompleteerror
    onblur
    oncancel
    oncanplay
    oncanplaythrough
    onchange
    onclick
    onclose
    oncontextmenu
    oncuechange
    ondblclick
    ondrag
    ondragend
    ondragenter
    ondragleave
    ondragover
    ondragstart
    ondrop
    ondurationchange
    onemptied
    onended
    onerror
    onfocus
    oninput
    oninvalid
    onkeydown
    onkeypress
    onkeyup
    onload
    onloadeddata
    onloadedmetadata
    onloadstart
    onmousedown
    onmouseenter
    onmouseleave
    onmousemove
    onmouseout
    onmouseover
    onmouseup
    onmousewheel
    onpause
    onplay
    onplaying
    onprogress
    onratechange
    onreset
    onresize
    onscroll
    onseeked
    onseeking
    onselect
    onshow
    onsort
    onstalled
    onsubmit
    onsuspend
    ontimeupdate
    ontoggle
    onvolumechange
    onwaiting
    accesskey
    anchor
    autocapitalize
    autocorrect
    autofocus
    class
    contenteditable
    dir
    draggable
    enterkeyhint
    exportparts
    hidden
    id
    inert
    inputmode
    is
    itemid
    itemprop
    itemref
    itemscope
    itemtype
    lang
    nonce
    part
    popover
    role
    slot
    spellcheck
    style
    tabindex
    title
    translate
    virtualkeyboardpolicy Experimental
    writingsuggestions
  )

  for attr <- global_attributes do
    def global_attribute?(unquote(attr)), do: true
  end

  def global_attribute?("data-" <> _rest), do: true
  def global_attribute?(_name), do: false
end
