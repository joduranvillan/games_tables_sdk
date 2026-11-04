// SPDX-FileCopyrightText: 2026 OpenTable Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

//! Proc-macros derive para juegos construidos sobre OpenTable SDK.
//!
//! Sin esto, cada `Command`/`Event`/`Resource`/`Component` de un juego
//! necesita escribir a mano `as_any()`, `#[derive(bevy_ecs::system::Resource)]`,
//! o el `impl bevy_ecs::component::Component` con su `Storage` asociado.
//! Estos cuatro derives generan exactamente ese boilerplate mecánico, nada
//! más - la lógica de juego (validaciones, reglas) sigue viviendo en el
//! crate del juego, no acá.
//!
//! Asume que el crate que los usa depende de `open_table_core` (siempre)
//! y, para `GameResource`/`GameComponent`, también de `bevy_ecs` bajo esos
//! nombres exactos.

use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, Data, DeriveInput, Fields};

/// `#[derive(GameCommand)]`: genera `impl Command for T` con `as_any()`.
///
/// Si un campo de la struct tiene el atributo `#[issuer]`, ese campo
/// (debe ser `PlayerId`, `Copy`) se usa para implementar `issuer()`.
/// Sin ese atributo, `issuer()` queda en el default (`None`) del trait.
#[proc_macro_derive(GameCommand, attributes(issuer))]
pub fn derive_game_command(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let ident = &input.ident;

    let pkg_name = std::env::var("CARGO_PKG_NAME").unwrap_or_default();
    let tag_name = if pkg_name.is_empty() {
        ident.to_string()
    } else {
        format!("{pkg_name}::{ident}")
    };

    let issuer_field = find_marked_field(&input.data, "issuer");

    let issuer_impl = match issuer_field {
        Some(field) => quote! {
            fn issuer(&self) -> ::std::option::Option<::open_table_core::ids::PlayerId> {
                ::std::option::Option::Some(self.#field)
            }
        },
        None => quote! {},
    };

    let expanded = quote! {
        #[::typetag::serde(name = #tag_name)]
        impl ::open_table_core::command::Command for #ident {
            fn clone_box(&self) -> ::std::boxed::Box<dyn ::open_table_core::command::Command> {
                ::std::boxed::Box::new(self.clone())
            }

            fn as_any(&self) -> &dyn ::std::any::Any {
                self
            }

            #issuer_impl
        }
    };

    expanded.into()
}

/// `#[derive(GameEvent)]`: genera `impl Event for T`.
///
/// Si un campo tiene el atributo `#[owner]`, ese campo (`PlayerId`, `Copy`)
/// se usa para que `visibility()` devuelva `Visibility::Owner(...)` - el
/// caso de "solo el dueño ve este evento" (cartas de mano, por ejemplo).
/// Sin ese atributo, `visibility()` queda en el default (`Public`).
#[proc_macro_derive(GameEvent, attributes(owner))]
pub fn derive_game_event(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let ident = &input.ident;

    let pkg_name = std::env::var("CARGO_PKG_NAME").unwrap_or_default();
    let tag_name = if pkg_name.is_empty() {
        ident.to_string()
    } else {
        format!("{pkg_name}::{ident}")
    };

    let owner_field = find_marked_field(&input.data, "owner");

    let visibility_impl = match owner_field {
        Some(field) => quote! {
            fn visibility(&self) -> ::open_table_core::visibility::Visibility {
                ::open_table_core::visibility::Visibility::Owner(self.#field)
            }
        },
        None => quote! {},
    };

    let expanded = quote! {
        #[::typetag::serde(name = #tag_name)]
        impl ::open_table_core::event::Event for #ident {
            fn as_any(&self) -> &dyn ::std::any::Any {
                self
            }

            #visibility_impl
        }
    };

    expanded.into()
}

/// `#[derive(GameResource)]`: implementa tanto `open_table_core::Resource`
/// (el marcador del SDK) como `bevy_ecs::resource::Resource` (lo que
/// `Session`/`RuleEngine` necesitan para poder insertarlo en el `World`).
///
/// En bevy_ecs 0.19+, Resource es un subtrait de Component. El `#[derive(Resource)]`
/// de bevy genera:
/// - Component con `StorageType::SparseSet`
/// - `register_required_components` que registra `IsResource` (sin esto, `resource_mut`
///   no puede localizar el recurso en el World en tiempo de ejecución)
/// - Resource como marcador vacío
#[proc_macro_derive(GameResource)]
pub fn derive_game_resource(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let ident = &input.ident;
    let (impl_generics, ty_generics, where_clause) = input.generics.split_for_impl();

    let expanded = quote! {
        impl #impl_generics ::open_table_core::resource::Resource for #ident #ty_generics #where_clause {}

        impl #impl_generics ::bevy_ecs::component::Component for #ident #ty_generics #where_clause {
            const STORAGE_TYPE: ::bevy_ecs::component::StorageType =
                ::bevy_ecs::component::StorageType::SparseSet;
            type Mutability = ::bevy_ecs::component::Mutable;

            fn register_required_components(
                _requiree: ::bevy_ecs::component::ComponentId,
                required_components: &mut ::bevy_ecs::component::RequiredComponentsRegistrator,
            ) {
                let resource_component_id =
                    if let ::std::option::Option::Some(id) =
                        required_components.components_registrator().component_id::<#ident #ty_generics>()
                    {
                        id
                    } else {
                        required_components.components_registrator().register_component::<#ident #ty_generics>()
                    };
                required_components.register_required::<::bevy_ecs::resource::IsResource>(
                    move || ::bevy_ecs::resource::IsResource::new(resource_component_id),
                );
            }
        }

        impl #impl_generics ::bevy_ecs::resource::Resource for #ident #ty_generics #where_clause {}
    };

    expanded.into()
}

/// `#[derive(GameComponent)]`: implementa tanto `open_table_core::Component`
/// como `bevy_ecs::component::Component` (con la estrategia de almacenamiento
/// TableStorage por defecto).
#[proc_macro_derive(GameComponent)]
pub fn derive_game_component(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let ident = &input.ident;
    let (impl_generics, ty_generics, where_clause) = input.generics.split_for_impl();

    let expanded = quote! {
        impl #impl_generics ::open_table_core::component::Component for #ident #ty_generics #where_clause {}
        impl #impl_generics ::bevy_ecs::component::Component for #ident #ty_generics #where_clause {
            const STORAGE_TYPE: ::bevy_ecs::component::StorageType = ::bevy_ecs::component::StorageType::Table;
            type Mutability = ::bevy_ecs::component::Mutable;
        }
    };

    expanded.into()
}

/// Busca, entre los campos de una struct con campos nombrados, el primero
/// marcado con el atributo `#[#marker]` (ej. `#[issuer]`, `#[owner]`).
fn find_marked_field(data: &Data, marker: &str) -> Option<syn::Ident> {
    let Data::Struct(data_struct) = data else {
        return None;
    };
    let Fields::Named(fields) = &data_struct.fields else {
        return None;
    };
    for field in &fields.named {
        if field.attrs.iter().any(|a| a.path().is_ident(marker)) {
            return field.ident.clone();
        }
    }
    None
}
