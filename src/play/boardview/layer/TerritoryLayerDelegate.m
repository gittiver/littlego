// -----------------------------------------------------------------------------
// Copyright 2011-2024 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Project includes
#import "TerritoryLayerDelegate.h"
#import "BoardViewCGLayerCache.h"
#import "BoardViewDrawingHelper.h"
#import "../../model/BoardViewMetrics.h"
#import "../../model/ScoringModel.h"
#import "../../../go/GoBoard.h"
#import "../../../go/GoBoardRegion.h"
#import "../../../go/GoGame.h"
#import "../../../go/GoPoint.h"
#import "../../../go/GoVertex.h"
#import "../../../main/ApplicationDelegate.h"
#import "../../../ui/CGDrawingHelper.h"
#import "../../../ui/UiSettingsModel.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for TerritoryLayerDelegate.
// -----------------------------------------------------------------------------
@interface TerritoryLayerDelegate()
@property(nonatomic, retain) ScoringModel* scoringModel;
/// @brief Store list of points to draw between notify:eventInfo:() and
/// drawLayer:inContext:(), and also between drawing cycles.
@property(nonatomic, retain) NSMutableDictionary* drawingPointsTerritory;
/// @brief Store list of points to draw between notify:eventInfo:() and
/// drawLayer:inContext:(), and also between drawing cycles.
@property(nonatomic, retain) NSMutableDictionary* drawingPointsStoneGroupState;
@end


@implementation TerritoryLayerDelegate

// -----------------------------------------------------------------------------
/// @brief Initializes a TerritoryLayerDelegate object.
///
/// @note This is the designated initializer of TerritoryLayerDelegate.
// -----------------------------------------------------------------------------
- (id) initWithTile:(id<Tile>)tile
            metrics:(BoardViewMetrics*)metrics
       scoringModel:(ScoringModel*)scoringModel
{
  // Call designated initializer of superclass (BoardViewLayerDelegateBase)
  self = [super initWithTile:tile metrics:metrics];
  if (! self)
    return nil;
  self.scoringModel = scoringModel;
  self.drawingPointsTerritory = [[[NSMutableDictionary alloc] initWithCapacity:0] autorelease];
  self.drawingPointsStoneGroupState = [[[NSMutableDictionary alloc] initWithCapacity:0] autorelease];
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this TerritoryLayerDelegate object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  // There are times when no TerritoryLayerDelegate instances are around to
  // react to events that invalidate the cached CGLayers, so the cached CGLayers
  // will inevitably become out-of-date. To prevent this, we invalidate the
  // CGLayers *NOW*.
  [self invalidateLayers];
  self.scoringModel = nil;
  self.drawingPointsTerritory = nil;
  self.drawingPointsStoneGroupState = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Invalidates the layers for marking up territory, and for marking dead
/// or seki stones.
///
/// When it is next invoked, drawLayer:inContext:() will re-create the layers.
// -----------------------------------------------------------------------------
- (void) invalidateLayers
{
  BoardViewCGLayerCache* cache = [BoardViewCGLayerCache sharedCache];
  [cache invalidateLayerOfType:BlackTerritoryLayerType];
  [cache invalidateLayerOfType:WhiteTerritoryLayerType];
  [cache invalidateLayerOfType:InconsistentFillColorTerritoryLayerType];
  [cache invalidateLayerOfType:InconsistentDotSymbolTerritoryLayerType];
  [cache invalidateLayerOfType:DeadStoneSymbolLayerType];
  [cache invalidateLayerOfType:BlackSekiStoneSymbolLayerType];
  [cache invalidateLayerOfType:WhiteSekiStoneSymbolLayerType];
}

// -----------------------------------------------------------------------------
/// @brief BoardViewLayerDelegate method.
// -----------------------------------------------------------------------------
- (void) notify:(enum BoardViewLayerDelegateEvent)event eventInfo:(id)eventInfo
{
  switch (event)
  {
    case BVLDEventBoardGeometryChanged:
    case BVLDEventBoardSizeChanged:
    {
      [self invalidateLayers];
      self.drawingPointsTerritory = [self calculateDrawingPointsTerritory];
      self.drawingPointsStoneGroupState = [self calculateDrawingPointsStoneGroupState];
      self.dirty = true;
      break;
    }
    case BVLDEventInvalidateContent:
    {
      self.drawingPointsTerritory = [self calculateDrawingPointsTerritory];
      self.drawingPointsStoneGroupState = [self calculateDrawingPointsStoneGroupState];
      self.dirty = true;
      break;
    }
    case BVLDEventScoreCalculationEnds:
    case BVLDEventInconsistentTerritoryMarkupTypeChanged:
    {
      NSMutableDictionary* oldDrawingPointsTerritory = self.drawingPointsTerritory;
      NSMutableDictionary* newDrawingPointsTerritory = [self calculateDrawingPointsTerritory];
      // The dictionary must contain the territory markup style so that the
      // dictionary comparison detects whether the territory color changed, or
      // the inconsistent territory markup type changed
      if (! [oldDrawingPointsTerritory isEqualToDictionary:newDrawingPointsTerritory])
      {
        self.drawingPointsTerritory = newDrawingPointsTerritory;
        // Re-draw the entire layer. Further optimization could be made here
        // by only drawing that rectangle which is actually affected by
        // self.drawingPointsTerritory.
        self.dirty = true;
      }

      if (event != BVLDEventInconsistentTerritoryMarkupTypeChanged)
      {
        NSMutableDictionary* oldDrawingPointsStoneGroupState = self.drawingPointsStoneGroupState;
        NSMutableDictionary* newDrawingPointsStoneGroupState = [self calculateDrawingPointsStoneGroupState];
        // The dictionary must contain the stone group state so that the
        // dictionary comparison detects whether a state change occurred
        if (! [oldDrawingPointsStoneGroupState isEqualToDictionary:newDrawingPointsStoneGroupState])
        {
          self.drawingPointsStoneGroupState = newDrawingPointsStoneGroupState;
          // Re-draw the entire layer. Further optimization could be made here
          // by only drawing that rectangle which is actually affected by
          // self.drawingPointsStoneGroupState.
          self.dirty = true;
        }
      }
      break;
    }
    default:
    {
      break;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief CALayerDelegate method.
// -----------------------------------------------------------------------------
- (void) drawLayer:(CALayer*)layer inContext:(CGContextRef)context
{
  CGRect tileRect = [CGDrawingHelper canvasRectForTile:self.tile
                                              withSize:self.boardViewMetrics.tileSize];
  GoBoard* board = [GoGame sharedGame].board;

  // Make sure that layers are created before drawing methods that use them are
  // invoked
  [self createLayersIfNecessaryWithContext:context];

  // Order is important: Later drawing methods draw their content over earlier
  // content
  [self drawTerritoryWithContext:context inTileRect:tileRect withBoard:board];
  [self drawStoneGroupStateWithContext:context inTileRect:tileRect withBoard:board];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for drawLayer:inContext:().
// -----------------------------------------------------------------------------
- (void) createLayersIfNecessaryWithContext:(CGContextRef)context
{
  BoardViewCGLayerCache* cache = [BoardViewCGLayerCache sharedCache];
  BoardViewCGLayerCacheEntry blackTerritoryLayerEntry = [cache layerOfType:BlackTerritoryLayerType];
  if (! blackTerritoryLayerEntry.isValid)
  {
    blackTerritoryLayerEntry.layer = CreateTerritoryLayer(context, TerritoryMarkupStyleBlack, self.boardViewMetrics);
    [cache setLayer:blackTerritoryLayerEntry.layer ofType:BlackTerritoryLayerType];
    CGLayerRelease(blackTerritoryLayerEntry.layer);
  }
  BoardViewCGLayerCacheEntry whiteTerritoryLayerEntry = [cache layerOfType:WhiteTerritoryLayerType];
  if (! whiteTerritoryLayerEntry.isValid)
  {
    whiteTerritoryLayerEntry.layer = CreateTerritoryLayer(context, TerritoryMarkupStyleWhite, self.boardViewMetrics);
    [cache setLayer:whiteTerritoryLayerEntry.layer ofType:WhiteTerritoryLayerType];
    CGLayerRelease(whiteTerritoryLayerEntry.layer);
  }
  BoardViewCGLayerCacheEntry inconsistentFillColorTerritoryLayerEntry = [cache layerOfType:InconsistentFillColorTerritoryLayerType];
  if (! inconsistentFillColorTerritoryLayerEntry.isValid)
  {
    inconsistentFillColorTerritoryLayerEntry.layer = CreateTerritoryLayer(context, TerritoryMarkupStyleInconsistentFillColor, self.boardViewMetrics);
    [cache setLayer:inconsistentFillColorTerritoryLayerEntry.layer ofType:InconsistentFillColorTerritoryLayerType];
    CGLayerRelease(inconsistentFillColorTerritoryLayerEntry.layer);
  }
  BoardViewCGLayerCacheEntry inconsistentDotSymbolTerritoryLayerEntry = [cache layerOfType:InconsistentDotSymbolTerritoryLayerType];
  if (! inconsistentDotSymbolTerritoryLayerEntry.isValid)
  {
    inconsistentDotSymbolTerritoryLayerEntry.layer = CreateTerritoryLayer(context, TerritoryMarkupStyleInconsistentDotSymbol, self.boardViewMetrics);
    [cache setLayer:inconsistentDotSymbolTerritoryLayerEntry.layer ofType:InconsistentDotSymbolTerritoryLayerType];
    CGLayerRelease(inconsistentDotSymbolTerritoryLayerEntry.layer);
  }
  BoardViewCGLayerCacheEntry deadStoneSymbolLayerEntry = [cache layerOfType:DeadStoneSymbolLayerType];
  if (! deadStoneSymbolLayerEntry.isValid)
  {
    deadStoneSymbolLayerEntry.layer = CreateDeadStoneSymbolLayer(context, self.boardViewMetrics);
    [cache setLayer:deadStoneSymbolLayerEntry.layer ofType:DeadStoneSymbolLayerType];
    CGLayerRelease(deadStoneSymbolLayerEntry.layer);
  }
  BoardViewCGLayerCacheEntry blackSekiStoneSymbolLayerEntry = [cache layerOfType:BlackSekiStoneSymbolLayerType];
  if (! blackSekiStoneSymbolLayerEntry.isValid)
  {
    blackSekiStoneSymbolLayerEntry.layer = CreateSquareSymbolLayer(context, self.boardViewMetrics.blackSekiSymbolColor, self.boardViewMetrics);
    [cache setLayer:blackSekiStoneSymbolLayerEntry.layer ofType:BlackSekiStoneSymbolLayerType];
    CGLayerRelease(blackSekiStoneSymbolLayerEntry.layer);
  }
  BoardViewCGLayerCacheEntry whiteSekiStoneSymbolLayerEntry = [cache layerOfType:WhiteSekiStoneSymbolLayerType];
  if (! whiteSekiStoneSymbolLayerEntry.isValid)
  {
    whiteSekiStoneSymbolLayerEntry.layer = CreateSquareSymbolLayer(context, self.boardViewMetrics.whiteSekiSymbolColor, self.boardViewMetrics);
    [cache setLayer:whiteSekiStoneSymbolLayerEntry.layer ofType:WhiteSekiStoneSymbolLayerType];
    CGLayerRelease(whiteSekiStoneSymbolLayerEntry.layer);
  }
}

// -----------------------------------------------------------------------------
/// @brief Private helper for drawLayer:inContext:().
// -----------------------------------------------------------------------------
- (void) drawTerritoryWithContext:(CGContextRef)context inTileRect:(CGRect)tileRect withBoard:(GoBoard*)board
{
  BoardViewCGLayerCache* cache = [BoardViewCGLayerCache sharedCache];
  BoardViewCGLayerCacheEntry blackTerritoryLayerEntry = [cache layerOfType:BlackTerritoryLayerType];
  BoardViewCGLayerCacheEntry whiteTerritoryLayerEntry = [cache layerOfType:WhiteTerritoryLayerType];
  BoardViewCGLayerCacheEntry inconsistentFillColorTerritoryLayerEntry = [cache layerOfType:InconsistentFillColorTerritoryLayerType];
  BoardViewCGLayerCacheEntry inconsistentDotSymbolTerritoryLayerEntry = [cache layerOfType:InconsistentDotSymbolTerritoryLayerType];

  [self.drawingPointsTerritory enumerateKeysAndObjectsUsingBlock:^(NSString* vertexString, NSNumber* territoryMarkupStyleAsNumber, BOOL* stop){
    enum TerritoryMarkupStyle territoryMarkupStyle = [territoryMarkupStyleAsNumber intValue];
    CGLayerRef layerToDraw = 0;
    switch (territoryMarkupStyle)
    {
      case TerritoryMarkupStyleBlack:
        layerToDraw = blackTerritoryLayerEntry.layer;
        break;
      case TerritoryMarkupStyleWhite:
        layerToDraw = whiteTerritoryLayerEntry.layer;
        break;
      case TerritoryMarkupStyleInconsistentFillColor:
        layerToDraw = inconsistentFillColorTerritoryLayerEntry.layer;
        break;
      case TerritoryMarkupStyleInconsistentDotSymbol:
        layerToDraw = inconsistentDotSymbolTerritoryLayerEntry.layer;
        break;
      default:
        return;
    }
    GoPoint* point = [board pointAtVertex:vertexString];
    [BoardViewDrawingHelper drawLayer:layerToDraw
                          withContext:context
                      centeredAtPoint:point
                       inTileWithRect:tileRect
                          withMetrics:self.boardViewMetrics];
  }];
}

// -----------------------------------------------------------------------------
/// @brief Private helper for drawLayer:inContext:().
// -----------------------------------------------------------------------------
- (void) drawStoneGroupStateWithContext:(CGContextRef)context inTileRect:(CGRect)tileRect withBoard:(GoBoard*)board
{
  BoardViewCGLayerCache* cache = [BoardViewCGLayerCache sharedCache];
  BoardViewCGLayerCacheEntry deadStoneSymbolLayerEntry = [cache layerOfType:DeadStoneSymbolLayerType];
  BoardViewCGLayerCacheEntry blackSekiStoneSymbolLayerEntry = [cache layerOfType:BlackSekiStoneSymbolLayerType];
  BoardViewCGLayerCacheEntry whiteSekiStoneSymbolLayerEntry = [cache layerOfType:WhiteSekiStoneSymbolLayerType];

  [self.drawingPointsStoneGroupState enumerateKeysAndObjectsUsingBlock:^(NSString* vertexString, NSNumber* stoneGroupStateAsNumber, BOOL* stop){
    GoPoint* point = [board pointAtVertex:vertexString];
    enum GoStoneGroupState stoneGroupState = [stoneGroupStateAsNumber intValue];
    CGLayerRef layerToDraw = 0;
    switch (stoneGroupState)
    {
      case GoStoneGroupStateDead:
      {
        layerToDraw = deadStoneSymbolLayerEntry.layer;
        break;
      }
      case GoStoneGroupStateSeki:
      {
        switch (point.stoneState)
        {
          case GoColorBlack:
            layerToDraw = blackSekiStoneSymbolLayerEntry.layer;
            break;
          case GoColorWhite:
            layerToDraw = whiteSekiStoneSymbolLayerEntry.layer;
            break;
          default:
            DDLogError(@"Unknown value %d for property point.stoneState", point.stoneState);
            return;
        }
        break;
      }
      case GoStoneGroupStateAlive:
      {
        // Don't draw anything for alive groups
        break;
      }
      default:
      {
        DDLogError(@"Unknown value %d for property point.region.stoneGroupState", stoneGroupState);
        return;
      }
    }
    [BoardViewDrawingHelper drawLayer:layerToDraw
                          withContext:context
                      centeredAtPoint:point
                       inTileWithRect:tileRect
                          withMetrics:self.boardViewMetrics];
  }];
}

// -----------------------------------------------------------------------------
/// @brief Returns a dictionary that identifies the points whose intersections
/// are located on this tile, and the markup style that should be used to draw
/// the territory for these points.
///
/// Dictionary keys are NSString objects that contain the intersection vertex.
/// The vertex string can be used to get the GoPoint object that corresponds to
/// the intersection.
///
/// Dictionary values are NSNumber objects that store a TerritoryMarkupStyle
/// enum value. The value identifies the layer that needs to be drawn at the
/// intersection.
// -----------------------------------------------------------------------------
- (NSMutableDictionary*) calculateDrawingPointsTerritory
{
  NSMutableDictionary* drawingPoints = [[[NSMutableDictionary alloc] initWithCapacity:0] autorelease];
  if ([ApplicationDelegate sharedDelegate].uiSettingsModel.uiAreaPlayMode != UIAreaPlayModeScoring)
    return drawingPoints;

  enum InconsistentTerritoryMarkupType inconsistentTerritoryMarkupType = self.scoringModel.inconsistentTerritoryMarkupType;

  // TODO: Currently we always iterate over all points. This could be
  // optimized: If the tile rect stays the same, we should already know which
  // points intersect with the tile, so we could fall back on a pre-filtered
  // list of points. On a 19x19 board this could save us quite a bit of time:
  // 381 points are iterated on 16 tiles (iPhone), i.e. over 6000 iterations.
  // on iPad where there are more tiles it is even worse.
  [self calculateDrawingPointsOnTileWithCallback:^bool(GoPoint* point, bool* stop)
  {
    enum GoColor territoryColor = point.region.territoryColor;
    enum TerritoryMarkupStyle territoryMarkupStyle;
    switch (territoryColor)
    {
      case GoColorBlack:
      {
        territoryMarkupStyle = TerritoryMarkupStyleBlack;
        break;
      }
      case GoColorWhite:
      {
        territoryMarkupStyle = TerritoryMarkupStyleWhite;
        break;
      }
      case GoColorNone:
      {
        if (! point.region.territoryInconsistencyFound)
          return false;  // territory is truly neutral, no markup needed
        switch (inconsistentTerritoryMarkupType)
        {
          case InconsistentTerritoryMarkupTypeNeutral:
            return false;  // territory is inconsistent, but user does not want markup
          case InconsistentTerritoryMarkupTypeDotSymbol:
            territoryMarkupStyle = TerritoryMarkupStyleInconsistentDotSymbol;
            break;
          case InconsistentTerritoryMarkupTypeFillColor:
            territoryMarkupStyle = TerritoryMarkupStyleInconsistentFillColor;
            break;
          default:
            DDLogError(@"Unknown value %d for property ScoringModel.inconsistentTerritoryMarkupType", inconsistentTerritoryMarkupType);
            return false;
        }
        break;
      }
      default:
      {
        DDLogError(@"Unknown value %d for property point.region.territoryColor", territoryColor);
        return false;
      }
    }

    NSNumber* territoryMarkupStyleAsNumber = [[[NSNumber alloc] initWithInt:territoryMarkupStyle] autorelease];
    [drawingPoints setObject:territoryMarkupStyleAsNumber forKey:point.vertex.string];

    return true;
  }];

  return drawingPoints;
}

// -----------------------------------------------------------------------------
/// @brief Returns a dictionary that identifies the points whose intersections
/// are located on this tile, and the stone group state of the region that each
/// point belongs to.
///
/// Dictionary keys are NSString objects that contain the intersection vertex.
/// The vertex string can be used to get the GoPoint object that corresponds to
/// the intersection.
///
/// Dictionary values are NSNumber objects that store a GoStoneGroupState enum
/// value.
// -----------------------------------------------------------------------------
- (NSMutableDictionary*) calculateDrawingPointsStoneGroupState
{
  NSMutableDictionary* drawingPoints = [[[NSMutableDictionary alloc] initWithCapacity:0] autorelease];
  GoGame* game = [GoGame sharedGame];
  if ([ApplicationDelegate sharedDelegate].uiSettingsModel.uiAreaPlayMode != UIAreaPlayModeScoring)
    return drawingPoints;

  CGRect tileRect = [CGDrawingHelper canvasRectForTile:self.tile
                                              withSize:self.boardViewMetrics.tileSize];

  // TODO: Currently we always iterate over all points. This could be
  // optimized: If the tile rect stays the same, we should already know which
  // points intersect with the tile, so we could fall back on a pre-filtered
  // list of points. On a 19x19 board this could save us quite a bit of time:
  // 381 points are iterated on 16 tiles (iPhone), i.e. over 6000 iterations.
  // on iPad where there are more tiles it is even worse.
  NSEnumerator* enumerator = [game.board pointEnumerator];
  GoPoint* point;
  while (point = [enumerator nextObject])
  {
    if (! point.hasStone)
      continue;
    CGRect stoneRect = [BoardViewDrawingHelper canvasRectForStoneAtPoint:point
                                                                 metrics:self.boardViewMetrics];
    if (! CGRectIntersectsRect(tileRect, stoneRect))
      continue;
    enum GoStoneGroupState stoneGroupState = point.region.stoneGroupState;
    NSNumber* stoneGroupStateAsNumber = [[[NSNumber alloc] initWithInt:stoneGroupState] autorelease];
    [drawingPoints setObject:stoneGroupStateAsNumber forKey:point.vertex.string];
  }

  return drawingPoints;
}

@end
