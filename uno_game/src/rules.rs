use crate::board::{CardColor, CardValue, UnoState};
use crate::commands::{DrawCardCommand, InterceptCommand, PlayCardCommand};
use crate::events::{
    CardPlayedEvent, CardsDrawnEvent, DrewAndPlayedEvent, GameOverEvent, InterceptedEvent,
    PlayerSkippedEvent, TurnReversedEvent,
};
use open_table_engine::prelude::*;

pub fn build_uno_rules() -> RuleEngine {
    let mut rules = RuleEngine::new();

    rules.register::<PlayCardCommand, _>(|cmd, world| {
        let players_count = world.resource::<TurnResource>().0.players().len();
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not your turn".into(),
            });
        }

        let mut events: Vec<Box<dyn Event>> = vec![];
        let cards_left;
        let played_card;
        let mut skips = 0;

        {
            let mut state = world.resource_mut::<UnoState>();
            let hand = state.hands.get(&cmd.player).unwrap();
            if cmd.card_index >= hand.len() {
                return Err(EngineError::InvalidCommand {
                    reason: "Invalid card index".into(),
                });
            }

            let card = hand[cmd.card_index];
            if !state.is_playable(&card) {
                return Err(EngineError::InvalidCommand {
                    reason: "Card is not playable".into(),
                });
            }

            if card.value == CardValue::WildDrawFour {
                if hand.iter().any(|c| c.color == state.active_color) {
                    return Err(EngineError::InvalidCommand {
                        reason:
                            "Cannot play Wild Draw Four when holding a card matching active color"
                                .into(),
                    });
                }
                state.wild_draw_four_illegal = false;
            }

            let is_wild = card.color == CardColor::WildColor;
            if is_wild && cmd.chosen_color.is_none() {
                return Err(EngineError::InvalidCommand {
                    reason: "Must choose a color for wild card".into(),
                });
            }
            if !is_wild && cmd.chosen_color.is_some() {
                return Err(EngineError::InvalidCommand {
                    reason: "Cannot choose color for non-wild card".into(),
                });
            }

            let new_color = if is_wild {
                cmd.chosen_color.unwrap()
            } else {
                card.color
            };
            state.active_color = new_color;

            if card.value == CardValue::DrawTwo {
                state.draw_penalty += 2;
            } else if card.value == CardValue::WildDrawFour {
                state.draw_penalty += 4;
            }

            let hand = state.hands.get_mut(&cmd.player).unwrap();
            let card_obj = hand.remove(cmd.card_index);
            cards_left = hand.len();
            state.discard_pile.push(card_obj);
            played_card = Some(card_obj);

            events.push(Box::new(CardPlayedEvent {
                player: cmd.player,
                card: card_obj,
                new_color,
            }));
        } // state dropped here

        if cards_left == 0 {
            events.push(Box::new(GameOverEvent { winner: cmd.player }));
            return Ok(events);
        }

        let card = played_card.unwrap();
        match card.value {
            CardValue::Reverse => {
                if players_count == 2 {
                    skips = 1;
                } else {
                    world.resource_mut::<TurnResource>().0.reverse_direction();
                    events.push(Box::new(TurnReversedEvent));
                }
            }
            CardValue::Skip => {
                skips = 1;
            }
            _ => {}
        }

        if skips > 0 {
            let next_player = world.resource::<TurnResource>().0.peek_next();
            events.push(Box::new(PlayerSkippedEvent {
                skipped_player: next_player,
            }));
            world.resource_mut::<TurnResource>().0.advance_n(skips + 1);
        } else {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules.register::<DrawCardCommand, _>(|cmd, world| {
        let players_count = world.resource::<TurnResource>().0.players().len();
        if !world.resource::<TurnResource>().0.is_current(cmd.player) {
            return Err(EngineError::InvalidCommand {
                reason: "Not your turn".into(),
            });
        }

        let penalty = world.resource::<UnoState>().draw_penalty;

        if penalty > 0 {
            let count_to_draw = {
                let mut state = world.resource_mut::<UnoState>();
                state.draw_penalty = 0;
                penalty
            };

            for _ in 0..count_to_draw {
                let needs_reshuffle = {
                    let s = world.resource::<UnoState>();
                    s.deck.is_empty() && s.discard_pile.len() > 1
                };
                if needs_reshuffle {
                    let mut deck_for_shuffle = {
                        let mut s = world.resource_mut::<UnoState>();
                        let top = s.discard_pile.pop().unwrap();
                        let mut pile = std::mem::take(&mut s.discard_pile);
                        s.deck.append(&mut pile);
                        let deck = std::mem::take(&mut s.deck);
                        s.discard_pile.push(top);
                        deck
                    };
                    world
                        .resource_mut::<RandomResource>()
                        .0
                        .shuffle(&mut deck_for_shuffle);
                    world.resource_mut::<UnoState>().deck = deck_for_shuffle;
                }
                if let Some(card) = world.resource_mut::<UnoState>().deck.pop() {
                    world
                        .resource_mut::<UnoState>()
                        .hands
                        .entry(cmd.player)
                        .or_default()
                        .push(card);
                }
            }

            let events: Vec<Box<dyn Event>> = vec![Box::new(CardsDrawnEvent {
                player: cmd.player,
                count: count_to_draw,
            })];
            world.resource_mut::<TurnResource>().0.advance();
            return Ok(events);
        }

        let needs_reshuffle = {
            let s = world.resource::<UnoState>();
            s.deck.is_empty() && s.discard_pile.len() > 1
        };
        if needs_reshuffle {
            let mut deck_for_shuffle = {
                let mut s = world.resource_mut::<UnoState>();
                let top = s.discard_pile.pop().unwrap();
                let mut pile = std::mem::take(&mut s.discard_pile);
                s.deck.append(&mut pile);
                let deck = std::mem::take(&mut s.deck);
                s.discard_pile.push(top);
                deck
            };
            world
                .resource_mut::<RandomResource>()
                .0
                .shuffle(&mut deck_for_shuffle);
            world.resource_mut::<UnoState>().deck = deck_for_shuffle;
        }

        let drawn_card = match world.resource_mut::<UnoState>().deck.pop() {
            Some(card) => card,
            None => {
                world.resource_mut::<TurnResource>().0.advance();
                return Ok(vec![]);
            }
        };

        let is_playable = {
            let state = world.resource::<UnoState>();
            state.is_playable(&drawn_card)
        };

        if is_playable {
            let mut events: Vec<Box<dyn Event>> = vec![];
            let new_color;
            let mut skips = 0;
            let cards_left;

            {
                let mut state = world.resource_mut::<UnoState>();
                new_color = if drawn_card.color == CardColor::WildColor {
                    state.active_color
                } else {
                    drawn_card.color
                };
                state.active_color = new_color;

                if drawn_card.value == CardValue::DrawTwo {
                    state.draw_penalty += 2;
                } else if drawn_card.value == CardValue::WildDrawFour {
                    state.draw_penalty += 4;
                }

                state.discard_pile.push(drawn_card);
                let hand = state.hands.get(&cmd.player).unwrap();
                cards_left = hand.len();

                events.push(Box::new(DrewAndPlayedEvent {
                    player: cmd.player,
                    card: drawn_card,
                    new_color,
                }));
            }

            if cards_left == 0 {
                events.push(Box::new(GameOverEvent { winner: cmd.player }));
                return Ok(events);
            }

            match drawn_card.value {
                CardValue::Reverse => {
                    if players_count == 2 {
                        skips = 1;
                    } else {
                        world.resource_mut::<TurnResource>().0.reverse_direction();
                        events.push(Box::new(TurnReversedEvent));
                    }
                }
                CardValue::Skip => {
                    skips = 1;
                }
                _ => {}
            }

            if skips > 0 {
                let next_player = world.resource::<TurnResource>().0.peek_next();
                events.push(Box::new(PlayerSkippedEvent {
                    skipped_player: next_player,
                }));
                world.resource_mut::<TurnResource>().0.advance_n(skips + 1);
            } else {
                world.resource_mut::<TurnResource>().0.advance();
            }

            Ok(events)
        } else {
            {
                let mut state = world.resource_mut::<UnoState>();
                state.hands.entry(cmd.player).or_default().push(drawn_card);
            }

            let events: Vec<Box<dyn Event>> = vec![Box::new(CardsDrawnEvent {
                player: cmd.player,
                count: 1,
            })];
            world.resource_mut::<TurnResource>().0.advance();
            Ok(events)
        }
    });

    rules.register::<InterceptCommand, _>(|cmd, world| {
        let players_count = world.resource::<TurnResource>().0.players().len();
        let mut events: Vec<Box<dyn Event>> = vec![];
        let cards_left;
        let intercepted_card;
        let mut skips = 0;

        {
            let mut state = world.resource_mut::<UnoState>();
            let top_discard = match state.discard_pile.last() {
                Some(&c) => c,
                None => {
                    return Err(EngineError::InvalidCommand {
                        reason: "Discard pile is empty".into(),
                    })
                }
            };

            let hand = match state.hands.get(&cmd.player) {
                Some(h) => h,
                None => {
                    return Err(EngineError::InvalidCommand {
                        reason: "Player not in game".into(),
                    })
                }
            };

            if cmd.card_index >= hand.len() {
                return Err(EngineError::InvalidCommand {
                    reason: "Invalid card index".into(),
                });
            }

            let card = hand[cmd.card_index];

            if card.color == CardColor::WildColor
                || card.value == CardValue::Wild
                || card.value == CardValue::WildDrawFour
            {
                return Err(EngineError::InvalidCommand {
                    reason: "Cannot intercept with wild card".into(),
                });
            }

            if card.color != top_discard.color || card.value != top_discard.value {
                return Err(EngineError::InvalidCommand {
                    reason: "Card is not identical to discard pile top card".into(),
                });
            }

            let hand_mut = state.hands.get_mut(&cmd.player).unwrap();
            let card_obj = hand_mut.remove(cmd.card_index);
            cards_left = hand_mut.len();
            state.active_color = card_obj.color;

            if card_obj.value == CardValue::DrawTwo {
                state.draw_penalty += 2;
            }

            state.discard_pile.push(card_obj);
            intercepted_card = card_obj;

            events.push(Box::new(InterceptedEvent {
                player: cmd.player,
                card: card_obj,
            }));
        }

        if cards_left == 0 {
            events.push(Box::new(GameOverEvent { winner: cmd.player }));
            return Ok(events);
        }

        world
            .resource_mut::<TurnResource>()
            .0
            .set_current_player(cmd.player);

        match intercepted_card.value {
            CardValue::Reverse => {
                if players_count == 2 {
                    skips = 1;
                } else {
                    world.resource_mut::<TurnResource>().0.reverse_direction();
                    events.push(Box::new(TurnReversedEvent));
                }
            }
            CardValue::Skip => {
                skips = 1;
            }
            _ => {}
        }

        if skips > 0 {
            let next_player = world.resource::<TurnResource>().0.peek_next();
            events.push(Box::new(PlayerSkippedEvent {
                skipped_player: next_player,
            }));
            world.resource_mut::<TurnResource>().0.advance_n(skips + 1);
        } else {
            world.resource_mut::<TurnResource>().0.advance();
        }

        Ok(events)
    });

    rules
}
