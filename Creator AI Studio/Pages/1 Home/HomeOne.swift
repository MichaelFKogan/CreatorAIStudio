//
//  Home.swift
//  AI Photo Generation
//
//  Created by Mike K on 10/9/25.
//

import AVKit
import SwiftUI

struct HomeOne: View {
    let resetTrigger: UUID

    var body: some View {
        NavigationView {
            ScrollView {
//                VStack{
//                    // Title
//                    VStack{
//
//                        Text("Unleash Your")
//                            .font(.system(size: 34, weight: .bold, design: .rounded))
//                            .foregroundStyle(
//                                LinearGradient(
//                                    colors: [.blue, .purple],
//                                    startPoint: .leading,
//                                    endPoint: .trailing
//                                )
//                            )
//                            .tracking(0.3)
//
//                        Text("Creativity with AI")
//                            .font(.system(size: 34, weight: .bold, design: .rounded))
//                            .foregroundStyle(
//                                LinearGradient(
//                                    colors: [.blue, .purple],
//                                    startPoint: .leading,
//                                    endPoint: .trailing
//                                )
//                            )
//                            .tracking(0.3)
//                    }
//                    .multilineTextAlignment(.center)
//
//                        // Subtitle
//                        Text("Transform your images and create amazing content with AI")
//                            .font(.body)
//                            .foregroundColor(.secondary)
//                            .multilineTextAlignment(.center)
//                            .padding(.horizontal)
//                            .lineSpacing(4)
//                }

                VStack(spacing: 20) {
//                    HomeRowSplit(title: "📸 Photo Filters", items: allPhotoFilters, diffAnimation: .scanHorizontal)
//                     HomeRowVideo(title: "📹 Video Filters", items: allVideoFilters)

//                     HomeRowSingle(title: "3D Caricature", items: Caricature)
//                     HomeRowSingle(title: "📸 Photobooth", items: photobooth)
//                     HomeRowSingle(title: "👻 Spooky", items: halloween)
//                     HomeRowSingle(title: "🎨 Artist", items: artist)
//                     HomeRowVideo(title: "🧜‍♀️ Mermaid", items: mermaidVideosItems)
//                     HomeRowSingle(title: "💎 Luxury", items: luxury)
//                     HomeRowSingle(title: "🎮 Video Games", items: videogamesItems)

                    // //                    HomeRowAIVideoModels(title: "📹 Video Models", items: videoModelData)
                    // //                    HomeRowAIImageModels(title: "📸 Image Models", items: imageModelData)

//                     HomeRowSingle(title: "Chibi", items: chibi)
//                     HomeRowSingle(title: "Cute", items: cute)
//                     HomeRowSingle(title: "🍌 Nano Banana Two", items: nanoBananaTwo)

//                     HomeRowSingle(title: "🌳 Outdoor Photography", items: outdoorsPhotography)
//                     HomeRowSingle(title: "📷 Street Photography", items: streetPhotography)

//                     HomeRowSingle(title: "Fashion", items: fashion)

//                     HomeRowSingle(title: "Men's Fashion", items: mensfashion)
                    // //                    HomeRowSingle(title: "📷 Themed Portraits", items: themedPortraits)

//                     HomeRowSingle(title: "👔 Professional Headshots", items: linkedInHeadshots)

//                    HomeRowSplit(title: "❤️ Relationships", items: relationshipItems, diffAnimation: .flipCard)
//                    HomeRowVideo(title: "❤️ Relationships", items: relationshipVideosItems)

//                    HomeRowVideo(title: "📈 Trending", items: transformyourphotosItems)
//                    HomeRowVideo(title: "💯 Popular", items: funItems)
//
                    ////                    HomeRowVideo(title: "🎃 Halloween", items: halloweenItems)
//                    HomeRowVideo(title: "🎃 Halloween", items: texttovideoItems)
//
//                    HomeRowVideo(title: "For The Girls", items: forthegirlsItems)
                    ////                    HomeRowVideo(title: "For The Guys", items: fortheguysItems)

//                    HomeRowVideo(title: "❤️ Relationships", items: relationshipItems, diffAnimation: .flipCard)
//                    HomeRowVideo(title: "Family", items: fortheguysItems)

//                    HomeRowVideo(title: "🎮 Video Game Videos", items: videogamesVideosItems)
//
                    ////                  HomeRowVideo(title: "Trending", items: trendingItem, diffAnimation: .scanHorizontal)
//
//
//                    HomeRowSplit(title: "Anime", items: animeItems, diffAnimation: .scanHorizontal)
//                    HomeRowSplit(title: "🦸‍♂️ Action Figures", items: actionfigureItems, diffAnimation: .scanHorizontal)
//
//                    HomeRowSingle(title: "🎲 Random", items: randomItems)
//
                    ////                    HomeRowSplit(title: "❤️ Relationships", items: relationshipItems, diffAnimation: .flipCard)
//
//                    HomeRowSplit(title: "💫 Futuristic", items: futuristicItems, diffAnimation: .scanHorizontal)
//                    HomeRowSplit(title: "📸 Photography", items: photographyItems, diffAnimation: .crossfade)
//
//                    HomeRowSplit(title: "😂 Pranks", items: prankItems, diffAnimation: .slider)
                    ////                    HomeRowSplit(title: "❤️ Relationships", items: relationshipItems, diffAnimation: .flipCard)
                    ////                    HomeRowSplit(title: "🧑‍🧑‍🧒 Family", items: familyItems, diffAnimation: .crossfade)

//                        .padding(.bottom, 200)
                }
            }
//            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("AI Creator Studio")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .font(.system(size: 8))
                        Text("$5.00")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("credits left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.secondary.opacity(0.1)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    )
                }
            }

//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: {
//                        themeManager.toggleTheme()
//                    }) {
//                        Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
//                            .foregroundColor(.primary)
//                    }
//                }
//            }
        }
        .id(resetTrigger) // Reset navigation stack when resetTrigger changes
    }
}
