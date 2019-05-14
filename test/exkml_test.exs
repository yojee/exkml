defmodule ExkmlTest do
  use ExUnit.Case
  import TestHelper
  alias Exkml.{
    Placemark,
    Point,
    Line,
    Polygon,
    Multigeometry
  }

  test "names and descriptions" do
    assert "names_and_descriptions"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [%Point{x: 102.0, y: 0.5}],
        attrs: %{
          "name" => "foo",
          "description" => "foofoo",
        }
      },
      %Placemark{
        geoms: [%Point{x: 103.0, y: 1.5}],
        attrs: %{
          "name" => "bar",
          "description" => "barbar",
        }
      }
    ]
  end

  test "timespan" do
    "rainier"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.filter(fn
      %{geoms: [%Exkml.Point{}]} -> true
      _ -> false
    end)
    |> Enum.map(fn %{attrs: attrs} -> attrs end)
    |> Enum.each(fn %{"timespan_begin" => tsb, "timespan_end" => tse} ->
      assert tsb
      assert tse
    end)
  end

  def receive_placemarks(ref) do
    receive do
      {:placemarks, ^ref, from, placemarks} ->
        Exkml.ack(from, ref)
        placemarks ++ receive_placemarks(ref)
      {:done, ^ref} ->
        []
    end
  end

  test "points" do
    assert "simple_points"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [%Point{x: 102.0, y: 0.5}],
        attrs: %{
          "a_bool" => "false",
          "a_float" => "2.2",
          "a_num" => "2",
          "a_string" => "first value"
        }
      },
      %Placemark{
        geoms: [%Point{x: 103.0, y: 1.5}],
        attrs: %{
          "a_bool" => "true",
          "a_float" => "2.2",
          "a_num" => "2",
          "a_string" => "second value"
        }
      }
    ]
  end

  test "lines" do
    assert "simple_lines"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [%Line{points: [%Point{x: 100.0, y: 0.0}, %Point{x: 101.0, y: 1.0}]}],
        attrs: %{"a_string" => "first value"}
      },
      %Placemark{
        geoms: [%Line{points: [%Point{x: 101.0, y: 0.0}, %Point{x: 101.0, y: 1.0}]}],
        attrs: %{"a_string" => "second value"}
      }
    ]
  end

  test "polygons" do
    assert "simple_polygons"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [
          %Polygon{
            inner_boundaries: [
              %Line{points: [
                %Point{x: 100.2, y: 0.2},
                %Point{x: 100.8, y: 0.2},
                %Point{x: 100.8, y: 0.8},
                %Point{x: 100.2, y: 0.8},
                %Point{x: 100.2, y: 0.2}]
              }
            ],
            outer_boundary: %Line{points: [
              %Point{x: 100.0, y: 0.0},
              %Point{x: 101.0, y: 0.0},
              %Point{x: 101.0, y: 1.0},
              %Point{x: 100.0, y: 1.0},
              %Point{x: 100.0, y: 0.0}]
            }
          }
        ],
        attrs: %{"a_string" => "first value"}
      },
      %Placemark{
        geoms: [
          %Polygon{
            inner_boundaries: [
              %Line{points: [
                %Point{x: 100.2, y: 0.2},
                %Point{x: 100.8, y: 0.2},
                %Point{x: 100.8, y: 0.8},
                %Point{x: 100.2, y: 0.8},
                %Point{x: 100.2, y: 0.2}]
              }
            ],
            outer_boundary: %Line{
              points: [
                %Point{x: 100.0, y: 0.0},
                %Point{x: 101.0, y: 0.0},
                %Point{x: 101.0, y: 1.0},
                %Point{x: 100.0, y: 1.0},
                %Point{x: 100.0, y: 0.0}
            ]
          }
        }
      ],
      attrs: %{"a_string" => "second value"}
    }]
  end

  test "multipoints" do
    assert "simple_multipoints"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [
          %Multigeometry{geoms: [
            %Point{x: 100.0, y: 0.0},
            %Point{x: 101.0, y: 1.0}
          ]}
        ],
        attrs: %{"a_string" => "first value"}
      },
      %Placemark{
        geoms: [
          %Multigeometry{geoms: [
            %Point{x: 101.0, y: 0.0},
            %Point{x: 101.0, y: 1.0}
          ]}
        ],
        attrs: %{"a_string" => "second value"}
      }
    ]
  end

  test "multilines" do
    assert "simple_multilines"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [
          %Multigeometry{geoms: [
            %Line{points: [
              %Point{x: 100.0, y: 0.0},
              %Point{x: 101.0, y: 1.0}]},
            %Line{points: [%Point{x: 102.0, y: 2.0},
              %Point{x: 103.0, y: 3.0}]}]
          }
        ],
        attrs: %{"a_string" => "first value"}
      },
      %Placemark{
        geoms: [
          %Multigeometry{geoms: [
            %Line{points: [
              %Point{x: 101.0, y: 0.0},
              %Point{x: 102.0, y: 1.0}]},
            %Line{points: [
              %Point{x: 102.0, y: 2.0},
              %Point{x: 103.0, y: 3.0}]}]
          }
        ],
        attrs: %{"a_string" => "second value"}
      }
    ]
  end

  test "multipolygons" do
    assert "simple_multipolygons"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [%Multigeometry{geoms: [%Polygon{inner_boundaries: [],
          outer_boundary: %Line{points: [%Point{x: 102.0, y: 2.0},
           %Point{x: 103.0, y: 2.0}, %Point{x: 103.0, y: 3.0},
           %Point{x: 102.0, y: 3.0}, %Point{x: 102.0, y: 2.0}]}},
          %Polygon{inner_boundaries: [%Line{points: [%Point{x: 100.2,
             y: 0.2}, %Point{x: 100.8, y: 0.2},
            %Point{x: 100.8, y: 0.8}, %Point{x: 100.2, y: 0.8},
            %Point{x: 100.2, y: 0.2}]}],
          outer_boundary: %Line{points: [%Point{x: 100.0, y: 0.0},
           %Point{x: 101.0, y: 0.0}, %Point{x: 101.0, y: 1.0},
           %Point{x: 100.0, y: 1.0}, %Point{x: 100.0, y: 0.0}]}}]}],
        attrs: %{"a_string" => "first value"}
      },
      %Placemark{
        geoms: [%Multigeometry{geoms: [%Polygon{inner_boundaries: [],
            outer_boundary: %Line{points: [%Point{x: 103.0, y: 2.0},
             %Point{x: 102.0, y: 2.0}, %Point{x: 103.0, y: 3.0},
             %Point{x: 102.0, y: 3.0}, %Point{x: 103.0, y: 2.0}]}},
            %Polygon{inner_boundaries: [%Line{points: [%Point{x: 100.2,
               y: 0.2}, %Point{x: 100.8, y: 0.2},
              %Point{x: 100.8, y: 0.8}, %Point{x: 100.2, y: 0.8},
              %Point{x: 100.2, y: 0.2}]}],
            outer_boundary: %Line{points: [%Point{x: 100.0, y: 0.0},
             %Point{x: 101.0, y: 0.0}, %Point{x: 101.0, y: 1.0},
             %Point{x: 100.0, y: 1.0}, %Point{x: 100.0, y: 0.0}]}}]}],
        attrs: %{"a_string" => "second value"}
      }
    ]
  end

  test "data instead of SimpleData" do
    assert "untyped_simple_points"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [%Point{x: 102.0, y: 0.5}],
        attrs: %{
          "a_bool" => "false",
          "a_float" => "2.2",
          "a_num" => "2",
          "a_string" => "first value"
        }
      },
      %Placemark{
        geoms: [%Point{x: 103.0, y: 1.5}],
        attrs: %{
          "a_bool" => "true",
          "a_float" => "2.2",
          "a_num" => "2",
          "a_string" => "second value"
        }
      }
    ]
  end

  test "points and lines" do
    assert "points_and_lines_multigeom_sans_schema"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([]) == [
      %Placemark{
        geoms: [%Multigeometry{
          geoms: [
            %Point{x: 102.0, y: 0.5},
            %Line{points: [
              %Point{x: 101.0, y: 0.0},
              %Point{x: 101.0, y: 1.0}
            ]}
          ]
        }],
        attrs: %{"a_string" => "first value"}
      }
    ]
  end

  test "3 dimension" do
    assert "line_extra_dimension"
    |> kml_fixture
    |> Exkml.stream!()
    |> Enum.into([])
    |> Enum.each(fn %Placemark{geoms: [%Line{points: points}]} ->
      Enum.each(points, fn %Point{z: z} -> assert z != nil end)
    end)
  end

  @tag timeout: 1000
  test "malformed" do
    assert_raise Exkml.KMLParseError, ~r"ended prematurely", fn ->
      "malformed_kml"
      |> kml_fixture
      |> Exkml.stream!()
      |> Enum.into([])
    end
  end


  Enum.each([
    {"boundaries", [Multigeometry], 163},
    {"cgis-en-6393", [Point], 233},
    {"la_bikelanes", [Multigeometry, Line], 12844},
    {"noaa", [Point], 227},
    {"terrassa", [Multigeometry, Point], 73},
    {"wards", [Polygon, Multigeometry], 53}
  ], fn {name, kinds, expected_length} ->
    test "smoke #{name}" do
      expected_set = MapSet.new(unquote(kinds))

      "smoke/#{unquote(name)}"
      |> kml_fixture
      |> Exkml.stream!()
      |> compare_stream(unquote(expected_length), expected_set)


      {:ok, stage} = "smoke/#{unquote(name)}"
      |> kml_fixture
      |> Exkml.stage()

      GenStage.stream([{stage, max_demand: 2, cancel: :temporary}])
      |> compare_stream(unquote(expected_length), expected_set)

    end
  end)

  def compare_stream(stream, expected_length, expected_set) do
    out = Enum.into(stream, [])

    assert length(out) == expected_length

    actual_set = Enum.flat_map(out, fn %Placemark{geoms: shapes} ->
      Enum.map(shapes, fn actual -> actual.__struct__ end)
    end)
    |> MapSet.new

    assert actual_set == expected_set
  end


  # test "prof" do
  #   proc = self()
  #   spawn(fn ->
  #     :fprof.trace([:start, {:procs, :all}])
  #     :timer.sleep(5_000)
  #     :fprof.trace([:stop])
  #     :fprof.profile
  #     :fprof.analyse({:dest, 'outfile.analysis'})
  #     send proc, :done
  #   end)

  #   out = "smoke/usbr"
  #   |> kml_fixture
  #   |> Exkml.stream!()
  #   |> Enum.take(1)

  #   receive do
  #     :done -> :ok
  #   end
  # end
end
