import YandexMapsMobile
/// this is version 4.1.0.4 by guy
class PlacemarkMapObjectController:
  NSObject,
  MapObjectController,
  YMKMapObjectTapListener,
  YMKMapObjectDragListener
{
  private let internallyControlled: Bool
  public let placemark: YMKPlacemarkMapObject
  private var consumeTapEvents: Bool = false
  public weak var controller: YandexMapController?
  public let id: String

  // Make this initializer failable to allow returning nil before super.init()
  public required init?(
    parent: YMKBaseMapObjectCollection,
    params: [String: Any],
    controller: YandexMapController
  ) {
    guard let pointDict = params["point"] as? [String: NSNumber] else {
      print("Error: 'point' parameter missing or invalid")
      return nil
    }
    let point = UtilsLite.pointFromJson(pointDict)

    var placemark: YMKPlacemarkMapObject? = nil

    if (parent is YMKClusterizedPlacemarkCollection) {
      placemark = (parent as! YMKClusterizedPlacemarkCollection).addPlacemark()
    } else if (parent is YMKMapObjectCollection) {
      placemark = (parent as! YMKMapObjectCollection).addPlacemark()
    } else {
      print("Error: parent is neither clusterized nor map object collection")
      return nil
    }

    guard let placemarkUnwrapped = placemark else {
      print("Error: Failed to create placemark")
      return nil
    }
    self.placemark = placemarkUnwrapped

    guard let id = params["id"] as? String else {
      print("Error: 'id' parameter missing or invalid")
      return nil
    }
    self.id = id
    self.controller = controller
    self.internallyControlled = false

    super.init()

    placemarkUnwrapped.userData = self.id
    placemarkUnwrapped.addTapListener(with: self)
    placemarkUnwrapped.setDragListenerWith(self)
    update(params)
  }

  public required init(
    placemark: YMKPlacemarkMapObject,
    params: [String: Any],
    controller: YandexMapController
  ) {
    self.placemark = placemark

    guard let id = params["id"] as? String else {
      print("Error: 'id' parameter missing or invalid")
      fatalError("Missing required 'id' parameter")
    }
    self.id = id
    self.controller = controller
    self.internallyControlled = true

    super.init()

    placemark.userData = self.id
    placemark.addTapListener(with: self)
    placemark.setDragListenerWith(self)
    update(params)
  }

  public func update(_ params: [String: Any]) {
    if (!internallyControlled) {
      if let pointDict = params["point"] as? [String: NSNumber] {
        placemark.geometry = UtilsLite.pointFromJson(pointDict)
      } else {
        print("Warning: 'point' parameter missing or invalid in update")
      }

      if let isVisibleNum = params["isVisible"] as? NSNumber {
        placemark.isVisible = isVisibleNum.boolValue
      }
    }

    if let zIndexNum = params["zIndex"] as? NSNumber {
      placemark.zIndex = zIndexNum.floatValue
    }

    if let isDraggableNum = params["isDraggable"] as? NSNumber {
      placemark.isDraggable = isDraggableNum.boolValue
    }

    if let opacityNum = params["opacity"] as? NSNumber {
      placemark.opacity = opacityNum.floatValue
    }

    if let directionNum = params["direction"] as? NSNumber {
      placemark.direction = directionNum.floatValue
    }

    setText(params["text"] as? [String: Any])
    setIcon(params["icon"] as? [String: Any])

    if let consumeTapEventsNum = params["consumeTapEvents"] as? NSNumber {
      consumeTapEvents = consumeTapEventsNum.boolValue
    }
  }

  public func remove() {
    if (internallyControlled) {
      return
    }

    placemark.parent.remove(with: placemark)
  }

  func onMapObjectDragStart(with mapObject: YMKMapObject) {
    controller?.mapObjectDragStart(id: id)
  }

  func onMapObjectDrag(with mapObject: YMKMapObject, point: YMKPoint) {
    controller?.mapObjectDrag(id: id, point: point)
  }

  func onMapObjectDragEnd(with mapObject: YMKMapObject) {
    controller?.mapObjectDragEnd(id: id)
  }

  func onMapObjectTap(with mapObject: YMKMapObject, point: YMKPoint) -> Bool {
    controller?.mapObjectTap(id: id, point: point)
    return consumeTapEvents
  }

  private func setText(_ text: [String: Any]?) {
    guard let text = text else { return }

    guard
      let textString = text["text"] as? String,
      let styleDict = text["style"] as? [String: Any]
    else {
      print("Warning: Invalid text or style data")
      return
    }

    placemark.setTextWithText(textString, style: getTextStyle(styleDict))
  }

  private func setIcon(_ icon: [String: Any]?) {
    guard let icon = icon else { return }

    guard let iconType = icon["type"] as? String else {
      print("Warning: Icon type missing")
      return
    }

    if (iconType == "single") {
      guard
        let style = icon["style"] as? [String: Any],
        let image = style["image"] as? [String: Any]
      else {
        print("Warning: Invalid icon style or image")
        return
      }

      placemark.setIconWith(getIconImage(image), style: getIconStyle(style))
    } else if (iconType == "composite") {
      guard let iconParts = icon["iconParts"] as? [[String: Any]] else {
        print("Warning: Invalid iconParts for composite icon")
        return
      }

      let compositeIcon = placemark.useCompositeIcon()
      for iconPart in iconParts {
        guard
          let style = iconPart["style"] as? [String: Any],
          let image = style["image"] as? [String: Any],
          let name = iconPart["name"] as? String
        else {
          print("Warning: Invalid iconPart data")
          continue
        }

        compositeIcon.setIconWithName(name, image: getIconImage(image), style: getIconStyle(style))
      }
    }
  }

  private func getIconImage(_ image: [String: Any]) -> UIImage {
    guard let type = image["type"] as? String else {
      return UIImage()
    }

    if (type == "fromAssetImage") {
      if let assetName = image["assetName"] as? String {
        let key = controller?.pluginRegistrar.lookupKey(forAsset: assetName) ?? assetName
        return UIImage(named: key) ?? UIImage()
      }
      return UIImage()
    }

    if (type == "fromBytes") {
      if let imageData = image["rawImageData"] as? FlutterStandardTypedData {
        return UIImage(data: imageData.data) ?? UIImage()
      }
      return UIImage()
    }

    return UIImage()
  }

  private func getTextStyle(_ style: [String: Any]) -> YMKTextStyle {
    let textStyle = YMKTextStyle()

    if let color = style["color"] as? NSNumber {
      textStyle.color = UtilsLite.uiColor(fromInt: color.int64Value)
    }

    if let outlineColor = style["outlineColor"] as? NSNumber {
      textStyle.outlineColor = UtilsLite.uiColor(fromInt: outlineColor.int64Value)
    }

    if let sizeNum = style["size"] as? NSNumber {
      textStyle.size = sizeNum.floatValue
    }

    if let offsetNum = style["offset"] as? NSNumber {
      textStyle.offset = offsetNum.floatValue
    }

    if let offsetFromIconNum = style["offsetFromIcon"] as? NSNumber {
      textStyle.offsetFromIcon = offsetFromIconNum.boolValue
    }

    if let textOptionalNum = style["textOptional"] as? NSNumber {
      textStyle.textOptional = textOptionalNum.boolValue
    }

    if let placementNum = style["placement"] as? NSNumber,
       let placement = YMKTextStylePlacement(rawValue: placementNum.uintValue) {
      textStyle.placement = placement
    }

    return textStyle
  }

  private func getIconStyle(_ style: [String: Any]) -> YMKIconStyle {
    let iconStyle = YMKIconStyle()

    if let tappableArea = style["tappableArea"] as? [String: Any] {
      iconStyle.tappableArea = UtilsLite.rectFromJson(tappableArea)
    }

    if let anchorDict = style["anchor"] as? [String: NSNumber] {
      iconStyle.anchor = NSValue(cgPoint: UtilsLite.rectPointFromJson(anchorDict))
    }

    if let zIndexNum = style["zIndex"] as? NSNumber {
      iconStyle.zIndex = zIndexNum
    }

    if let scaleNum = style["scale"] as? NSNumber {
      iconStyle.scale = scaleNum
    }

    if let visibleNum = style["visible"] as? NSNumber {
      iconStyle.visible = visibleNum.boolValue
    }

    if let flatNum = style["flat"] as? NSNumber {
      iconStyle.flat = flatNum.boolValue
    }

    if let rotationTypeNum = style["rotationType"] as? NSNumber,
       let rotationType = YMKIconStyleRotationType(rawValue: rotationTypeNum.uintValue) {
      iconStyle.rotationType = rotationType
    }

    if let anchorTypeNum = style["anchorType"] as? NSNumber,
       let anchorType = YMKIconStyleAnchorType(rawValue: anchorTypeNum.uintValue) {
      iconStyle.anchorType = anchorType
    }

    if let directionNum = style["direction"] as? NSNumber {
      iconStyle.direction = directionNum.floatValue
    }

    return iconStyle
  }
}
